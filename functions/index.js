
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { initializeApp } = require("firebase-admin/app");
const axios = require("axios");
const { GoogleGenerativeAI } = require("@google/generative-ai");

initializeApp();
const db = getFirestore();

// Helper for fallback question
const getFallbackQuest = () => {
    return {
        quest_type: "trivia",
        title: "Wilderness Survival",
        question: "What is an essential skill needed to survive in the wilderness?",
        options: ["Building a fire", "Typing fast", "Video gaming", "Sleeping"],
        correct_answer: "Building a fire",
        xp_reward: 50,
        location_name: "Wilderness Zone",
        location_id: "wilderness_fallback",
        coordinates: { lat: 0, lng: 0 }
    };
};

// Helper: Haversine distance in meters
function getDistanceFromLatLonInM(lat1, lon1, lat2, lon2) {
    const R = 6371e3; // Radius of the earth in m
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLon = (lon2 - lon1) * Math.PI / 180;
    const a = 
        Math.sin(dLat/2) * Math.sin(dLat/2) +
        Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * 
        Math.sin(dLon/2) * Math.sin(dLon/2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a)); 
    const d = R * c; // Distance in m
    return d;
}

/**
 * generateQuest (HTTPS Callable)
 * Accepts latitude and longitude.
 * Calls Google Places API to find nearby tourist attraction.
 * Calls Gemini to generate one of three quest types.
 * Stores secrets in Firestore.
 * Returns public quest info.
 */
exports.generateQuest = onCall(async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "User must be logged in to generate a quest.");
    }
    const uid = request.auth.uid;

    const { latitude, longitude } = request.data || {};
    if (!latitude || !longitude) {
        throw new HttpsError("invalid-argument", "Latitude and longitude are required.");
    }

    const placesApiKey = process.env.PLACES_API_KEY;
    const geminiApiKey = process.env.GEMINI_API_KEY;

    if (!placesApiKey || !geminiApiKey) {
        console.error("Missing API Keys");
        throw new HttpsError("internal", "Server configuration error.");
    }

    let locationData = { name: "", id: "", lat: latitude, lng: longitude };
    let questData = null;

    try {
        const placesUrl = `https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=${latitude},${longitude}&radius=500&type=tourist_attraction&key=${placesApiKey}`;
        const placesResponse = await axios.get(placesUrl);
        const results = placesResponse.data.results;

        if (!results || results.length === 0) {
             questData = getFallbackQuest();
             locationData.name = questData.location_name;
             locationData.id = questData.location_id;
        } else {
            const place = results[0];
            locationData.name = place.name;
            locationData.id = place.place_id;
            locationData.lat = place.geometry.location.lat;
            locationData.lng = place.geometry.location.lng;

            const contextText = `Location Name: ${place.name}. Address/Vicinity: ${place.vicinity}.`;

            const genAI = new GoogleGenerativeAI(geminiApiKey);
            const model = genAI.getGenerativeModel({
                model: "gemini-1.5-flash",
                generationConfig: { responseMimeType: "application/json" }
            });

            const prompt = `
You are a gamified travel app quest generator.
Given the following location details, randomly select ONE of three quest types: "trivia", "exploration", or "discovery".
Location context: ${contextText}

Return ONLY a valid JSON object.
If "trivia", format: {"quest_type": "trivia", "title": "...", "question": "...", "options": ["A", "B", "C", "D"], "correct_answer": "...", "xp_reward": 100}.
If "exploration", format: {"quest_type": "exploration", "title": "...", "description": "Cryptic clue to find the spot...", "xp_reward": 75}.
If "discovery", format: {"quest_type": "discovery", "title": "Visit ${place.name}", "unlocked_lore": "A fascinating, detailed historical fact or fun review about this specific place.", "xp_reward": 50}.
`;

            const result = await model.generateContent(prompt);
            let responseText = result.response.text();
            
            if (responseText.startsWith("\`\`\`json")) {
                responseText = responseText.replace(/\`\`\`json/g, "").replace(/\`\`\`/g, "").trim();
            }

            questData = JSON.parse(responseText);
        }

        // Store active quest with secrets
        const activeQuestPayload = {
            location_id: locationData.id,
            quest_type: questData.quest_type,
            xp_reward: questData.xp_reward,
            timestamp: FieldValue.serverTimestamp(),
            location_lat: locationData.lat,
            location_lng: locationData.lng
        };

        if (questData.quest_type === "trivia") {
            activeQuestPayload.correct_answer = questData.correct_answer;
        } else if (questData.quest_type === "discovery") {
            activeQuestPayload.unlocked_lore = questData.unlocked_lore;
        }

        await db.collection("active_quests").doc(uid).set(activeQuestPayload);

        // Strip secrets before returning to client
        const clientResponse = {
            quest_type: questData.quest_type,
            title: questData.title,
            xp_reward: questData.xp_reward,
            location_name: locationData.name,
            coordinates: { lat: locationData.lat, lng: locationData.lng }
        };

        if (questData.quest_type === "trivia") {
            clientResponse.question = questData.question;
            clientResponse.options = questData.options;
        } else if (questData.quest_type === "exploration") {
            clientResponse.description = questData.description;
        }

        return clientResponse;

    } catch (error) {
        console.error("Error generating quest", error);
        throw new HttpsError("internal", "Failed to generate quest.", error.message);
    }
});

/**
 * completeQuest (HTTPS Callable)
 * Accepts location_id, latitude, longitude, and selected_answer (if trivia)
 * Verifies answer/distance, handles XP, returns lore
 */
exports.completeQuest = onCall(async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "User must be logged in to complete a quest.");
    }
    const uid = request.auth.uid;

    const { location_id, latitude, longitude, selected_answer } = request.data || {};
    if (!location_id || !latitude || !longitude) {
        throw new HttpsError("invalid-argument", "location_id, latitude, and longitude are required.");
    }

    try {
        const activeQuestRef = db.collection("active_quests").doc(uid);
        const userRef = db.collection("users").doc(uid);
        const today = new Date().toISOString().split('T')[0];
        const completedQuestId = `${uid}_${location_id}_${today}`;
        const completedQuestRef = db.collection("completed_quests").doc(completedQuestId);

        return await db.runTransaction(async (transaction) => {
            const activeQuestDoc = await transaction.get(activeQuestRef);
            if (!activeQuestDoc.exists) {
                throw new HttpsError("not-found", "No active quest found.");
            }

            const questData = activeQuestDoc.data();
            
            if (questData.location_id !== location_id) {
                throw new HttpsError("invalid-argument", "Location ID does not match active quest.");
            }

            // GPS Distance check (must be within 50m) unless it's the fallback
            if (questData.location_id !== "wilderness_fallback") {
                const distance = getDistanceFromLatLonInM(latitude, longitude, questData.location_lat, questData.location_lng);
                if (distance > 50) {
                    throw new HttpsError("failed-precondition", `You are too far away! (${Math.round(distance)}m). You must be within 50m.`);
                }
            }

            // Trivia check
            if (questData.quest_type === "trivia") {
                if (!selected_answer) {
                    throw new HttpsError("invalid-argument", "selected_answer is required for trivia quests.");
                }
                if (questData.correct_answer !== selected_answer) {
                    transaction.delete(activeQuestRef);
                    return { success: false, message: "Incorrect answer.", xpAwarded: 0 };
                }
            }

            const completedDoc = await transaction.get(completedQuestRef);
            if (completedDoc.exists) {
                transaction.delete(activeQuestRef);
                throw new HttpsError("already-exists", "You have already completed a quest at this location today.");
            }

            // Provide rewards
            const userDoc = await transaction.get(userRef);
            let currentXp = 0;
            let currentLevel = 1;

            if (userDoc.exists) {
                const userData = userDoc.data();
                currentXp = userData.current_xp || 0;
                currentLevel = userData.level || 1;
            }

            const earnedXp = questData.xp_reward || 50;
            const newXp = currentXp + earnedXp;
            const newLevel = Math.floor(newXp / 100) + 1;

            if (!userDoc.exists) {
                transaction.set(userRef, { current_xp: newXp, level: newLevel });
            } else {
                transaction.update(userRef, { current_xp: newXp, level: newLevel });
            }

            transaction.set(completedQuestRef, {
                userId: uid,
                location_id: location_id,
                quest_type: questData.quest_type,
                date: today,
                timestamp: FieldValue.serverTimestamp()
            });

            transaction.delete(activeQuestRef);

            const responsePayload = { 
                success: true, 
                message: "Quest Complete!", 
                xpAwarded: earnedXp,
                newXp: newXp,
                newLevel: newLevel
            };

            if (questData.quest_type === "discovery" && questData.unlocked_lore) {
                responsePayload.unlocked_lore = questData.unlocked_lore;
            }

            return responsePayload;
        });

    } catch (error) {
        console.error("Error completing quest", error);
        if (error instanceof HttpsError) {
            throw error;
        }
        throw new HttpsError("internal", "Failed to complete quest.", error.message);
    }
});
