const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { initializeApp } = require("firebase-admin/app");
const axios = require("axios");
const { GoogleGenerativeAI } = require("@google/generative-ai");

initializeApp();
const db = getFirestore();

// Helper for fallback question
const getFallbackQuestion = () => {
    return {
        question: "What is an essential skill needed to survive in the wilderness?",
        options: ["Building a fire", "Typing fast", "Video gaming", "Sleeping"],
        correct_answer: "Building a fire",
        location_name: "Wilderness Zone",
        location_id: "wilderness_fallback",
        coordinates: { lat: 0, lng: 0 }
    };
};

/**
 * generateQuest (HTTPS Callable)
 * Accepts latitude and longitude.
 * Calls Google Places API to find nearby tourist attraction.
 * Calls Gemini to generate a trivia JSON.
 * Stores correct answer in Firestore.
 * Returns question, options, location info purely.
 */
exports.generateQuest = onCall({ secrets: ["PLACES_API_KEY", "GEMINI_API_KEY"] }, async (request) => {
    // 1. Verify Authentication
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

    let locationData = {
        name: "",
        id: "",
        lat: latitude,
        lng: longitude
    };
    
    let triviaData = null;

    try {
        // 2. Call Google Places API (Nearby Search)
        // Searching for tourist_attraction within 500m
        const placesUrl = `https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=${latitude},${longitude}&radius=500&type=tourist_attraction&key=${placesApiKey}`;
        const placesResponse = await axios.get(placesUrl);
        const results = placesResponse.data.results;

        if (!results || results.length === 0) {
            // Edge Case: 0 locations found
             triviaData = getFallbackQuestion();
             locationData.name = triviaData.location_name;
             locationData.id = triviaData.location_id;
        } else {
            // Take the first prominent place
            const place = results[0];
            locationData.name = place.name;
            locationData.id = place.place_id;
            locationData.lat = place.geometry.location.lat;
            locationData.lng = place.geometry.location.lng;

            const contextText = `Location Name: ${place.name}. Address/Vicinity: ${place.vicinity}. Provide a fun trivia question about this specific place or its immediate general local context.`;

            // 3. Call Gemini
            const genAI = new GoogleGenerativeAI(geminiApiKey);
            const model = genAI.getGenerativeModel({
                model: "gemini-1.5-flash",
                generationConfig: {
                    responseMimeType: "application/json",
                }
            });

            const prompt = `
You are a gamified travel app trivia generator. 
Given the following location details, create a multiple choice trivia question.
Location context: ${contextText}

Return ONLY a valid JSON object with the exact following structure (do not use markdown formatting tags):
{
    "question": "The trivia question text",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "correct_answer": "The exact string from options that is correct"
}
Ensure the correct_answer is exactly one of the strings in the options array.
`;

            const result = await model.generateContent(prompt);
            let responseText = result.response.text();
            
            // Clean up backticks if any
            if (responseText.startsWith("\`\`\`json")) {
                responseText = responseText.replace(/\`\`\`json/g, "").replace(/\`\`\`/g, "").trim();
            }

            triviaData = JSON.parse(responseText);
        }

        // 4. Store active quest
        await db.collection("active_quests").doc(uid).set({
            location_id: locationData.id,
            correct_answer: triviaData.correct_answer,
            timestamp: FieldValue.serverTimestamp()
        });

        // 5. Return sanitized data to client
        return {
            question: triviaData.question,
            options: triviaData.options,
            location_name: locationData.name,
            coordinates: {
                lat: locationData.lat,
                lng: locationData.lng
            }
        };

    } catch (error) {
        console.error("Error generating quest", error);
        throw new HttpsError("internal", "Failed to generate quest.", error.message);
    }
});

/**
 * submitAnswer (HTTPS Callable)
 * Accepts location_id and selected_answer
 * Verifies answer, checks for duplicate completions today
 * Awards XP using a transaction
 */
exports.submitAnswer = onCall(async (request) => {
    // 1. Verify Authentication
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "User must be logged in to submit an answer.");
    }
    const uid = request.auth.uid;

    const { location_id, selected_answer } = request.data || {};
    if (!location_id || !selected_answer) {
        throw new HttpsError("invalid-argument", "location_id and selected_answer are required.");
    }

    try {
        const activeQuestRef = db.collection("active_quests").doc(uid);
        const userRef = db.collection("users").doc(uid);
        
        // Define a unique ID for completed quest (User + Location + Date)
        // This prevents farming the same location on the same day.
        const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
        const completedQuestId = `${uid}_${location_id}_${today}`;
        const completedQuestRef = db.collection("completed_quests").doc(completedQuestId);

        return await db.runTransaction(async (transaction) => {
            // 2. Fetch active quest
            const activeQuestDoc = await transaction.get(activeQuestRef);
            if (!activeQuestDoc.exists) {
                throw new HttpsError("not-found", "No active quest found for this user.");
            }

            const questData = activeQuestDoc.data();
            
            // Verify location ID matches
            if (questData.location_id !== location_id) {
                throw new HttpsError("invalid-argument", "Location ID does not match active quest.");
            }

            // 3. Compare answer
            if (questData.correct_answer !== selected_answer) {
                // Delete active quest so they can't brute force
                transaction.delete(activeQuestRef);
                return { success: false, message: "Incorrect answer.", xpAwarded: 0 };
            }

            // 4. Check completed_quests for today
            const completedDoc = await transaction.get(completedQuestRef);
            if (completedDoc.exists) {
                // They already solved this today!
                transaction.delete(activeQuestRef);
                throw new HttpsError("already-exists", "You have already completed a quest at this location today.");
            }

            // 5. Provide rewards
            const userDoc = await transaction.get(userRef);
            let currentXp = 0;
            let currentLevel = 1;

            if (userDoc.exists) {
                const userData = userDoc.data();
                currentXp = userData.current_xp || 0;
                currentLevel = userData.level || 1;
            }

            const newXp = currentXp + 50;
            const newLevel = Math.floor(newXp / 100) + 1;

            if (!userDoc.exists) {
                transaction.set(userRef, { current_xp: newXp, level: newLevel });
            } else {
                transaction.update(userRef, { current_xp: newXp, level: newLevel });
            }

            // Log completion
            transaction.set(completedQuestRef, {
                userId: uid,
                location_id: location_id,
                date: today,
                timestamp: FieldValue.serverTimestamp()
            });

            // 6. Delete active quest
            transaction.delete(activeQuestRef);

            return { 
                success: true, 
                message: "Correct! You earned 50 XP.", 
                xpAwarded: 50,
                newXp: newXp,
                newLevel: newLevel
            };
        });

    } catch (error) {
        console.error("Error submitting answer", error);
        if (error instanceof HttpsError) {
            throw error;
        }
        throw new HttpsError("internal", "Failed to submit answer.", error.message);
    }
});
