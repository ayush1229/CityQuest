
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
exports.generateQuest = onCall({ timeoutSeconds: 120 }, async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "User must be logged in to generate a quest.");
    }
    const uid = request.auth.uid;

    const { latitude, longitude, radius } = request.data || {};
    if (!latitude || !longitude) {
        throw new HttpsError("invalid-argument", "Latitude and longitude are required.");
    }
    const searchRadius = radius || 500; // Default 500m

    const placesApiKey = process.env.PLACES_API_KEY;
    const geminiApiKey = process.env.GEMINI_API_KEY;

    if (!placesApiKey || !geminiApiKey) {
        console.error("Missing API Keys");
        throw new HttpsError("internal", "Server configuration error.");
    }

    try {
        const NIT_LAT = 31.7084;
        const NIT_LNG = 76.5273;
        
        const distToNit = getDistanceFromLatLonInM(latitude, longitude, NIT_LAT, NIT_LNG);
        const isAtHackathon = distToNit <= 2500;

        let generatedQuests = [];

        if (isAtHackathon) {
            console.log("Hackathon User Detected! Injecting Custom NIT Quests...");
            const nitLocations = [
                { 
                    id: "nit_oat", name: "Open Air Theatre (OAT)", lat: 31.7075, lng: 76.5278,
                    questData: {
                        quest_type: "discovery",
                        title: "Secrets of the OAT",
                        unlocked_lore: "The Open Air Theatre at NIT Hamirpur is the cultural heart of the campus. Built into the natural hillside terrain, it hosts the annual Nimbus tech fest, Hill'ffair cultural fest, and countless unforgettable performances under the starlit Himalayan sky. The acoustics of the amphitheatre are naturally amplified by the surrounding hills.",
                        xp_reward: 75
                    }
                },
                { 
                    id: "nit_auditorium", name: "NIT Hamirpur Auditorium", lat: 31.7081, lng: 76.5262,
                    questData: {
                        quest_type: "trivia",
                        title: "Auditorium Challenge",
                        question: "Which annual technical festival of NIT Hamirpur is one of the largest in North India?",
                        options: ["Nimbus", "Techfest", "Pragati", "Hillffair"],
                        correct_answer: "Nimbus",
                        xp_reward: 100
                    }
                },
                { 
                    id: "nit_sac", name: "Student Activity Centre (SAC)", lat: 31.7095, lng: 76.5280,
                    questData: {
                        quest_type: "exploration",
                        title: "The Hidden Hub",
                        description: "Find the building where creativity meets code — where robotics clubs test their bots and debaters sharpen their words. Look for the structure buzzing with student energy near the upper campus road.",
                        xp_reward: 80
                    }
                },
                { 
                    id: "nit_cse", name: "Computer Science Dept", lat: 31.7065, lng: 76.5269,
                    questData: {
                        quest_type: "discovery",
                        title: "Heart of Innovation",
                        unlocked_lore: "The Computer Science & Engineering department at NIT Hamirpur has produced numerous startup founders, competitive programmers, and tech leaders. The department houses state-of-the-art labs including AI/ML research facilities, and its students have represented India at ICPC World Finals multiple times.",
                        xp_reward: 75
                    }
                },
                { 
                    id: "nit_library", name: "Central Library", lat: 31.7088, lng: 76.5271,
                    questData: {
                        quest_type: "trivia",
                        title: "Library Lore",
                        question: "NIT Hamirpur was established in which year?",
                        options: ["1986", "1992", "2002", "1978"],
                        correct_answer: "1986",
                        xp_reward: 100
                    }
                }
            ];
            const today = new Date().toISOString().split('T')[0];
            for (const place of nitLocations) {
                const completedQuestId = `${uid}_${place.id}_${today}`;
                const completedDoc = await db.collection("completed_quests").doc(completedQuestId).get();
                
                if (!completedDoc.exists) {
                    generatedQuests.push({
                        locationData: { name: place.name, id: place.id, lat: place.lat, lng: place.lng },
                        questData: place.questData
                    });
                }
            }
        }

        // Standard Global Google Places Logic — always runs (even at hackathon, to add AI quests too)
        // Collect IDs of already-added quests to avoid duplicates
        const existingIds = new Set(generatedQuests.map(q => q.locationData.id));

        const placesUrl = `https://places.googleapis.com/v1/places:searchNearby`;
            const placesPayload = {
                includedTypes: ["tourist_attraction", "park", "museum", "university", "hindu_temple", "church", "mosque", "library", "stadium", "shopping_mall", "restaurant", "cafe"],
                maxResultCount: 20,
                locationRestriction: { circle: { center: { latitude: latitude, longitude: longitude }, radius: searchRadius * 1.0 } }
            };

            console.log(`[generateQuest] Searching Places API with radius=${searchRadius}m, types=${placesPayload.includedTypes.join(",")}`);

            let places = [];
            try {
                const placesResponse = await axios.post(placesUrl, placesPayload, { headers: { "X-Goog-Api-Key": placesApiKey, "X-Goog-FieldMask": "places.id,places.displayName,places.location,places.formattedAddress", "Content-Type": "application/json" } });
                places = placesResponse.data.places || [];
                console.log(`[generateQuest] Places API returned ${places.length} results`);
            } catch (placesErr) {
                console.error(`[generateQuest] Places API error: ${placesErr.response?.data?.error?.message || placesErr.message}`);
                places = [];
            }

            if (places.length === 0 && generatedQuests.length === 0) {
                 const fallback = getFallbackQuest();
                 generatedQuests.push({ locationData: { name: fallback.location_name, id: fallback.location_id, lat: latitude, lng: longitude }, questData: fallback });
            } else if (places.length > 0) {
                // Filter out duplicates (e.g. NIT locations already added)
                const newPlaces = places.filter(p => !existingIds.has(p.id));
                console.log(`[generateQuest] After dedup: ${newPlaces.length} new places to process`);

                const genAI = new GoogleGenerativeAI(geminiApiKey);
                const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash", generationConfig: { responseMimeType: "application/json" } });

                // Enforce quest type ratio: ~3 trivia : 3 discovery : 5 exploration (out of every 11)
                const typePattern = ["exploration", "trivia", "exploration", "discovery", "exploration", "trivia", "discovery", "exploration", "trivia", "discovery", "exploration"];

                // Process places in parallel for speed
                const questPromises = newPlaces.map(async (place, idx) => {
                    const assignedType = typePattern[idx % typePattern.length];
                    let locData = { name: place.displayName?.text || "Unknown Location", id: place.id, lat: place.location.latitude, lng: place.location.longitude };
                    const contextText = `Location Name: ${locData.name}. Address/Vicinity: ${place.formattedAddress || 'No Address'}.`;
                    
                    let prompt;
                    if (assignedType === "trivia") {
                        prompt = `You are a gamified travel app quest generator.\nGenerate a TRIVIA quest for this location.\nLocation context: ${contextText}\n\nReturn ONLY a valid JSON object in this format:\n{"quest_type": "trivia", "title": "...", "question": "An interesting trivia question about this place", "options": ["A", "B", "C", "D"], "correct_answer": "The correct option", "xp_reward": 100}`;
                    } else if (assignedType === "exploration") {
                        prompt = `You are a gamified travel app quest generator.\nGenerate an EXPLORATION quest for this location. The description should be a cryptic, mysterious clue that guides the player to discover this place.\nLocation context: ${contextText}\n\nReturn ONLY a valid JSON object in this format:\n{"quest_type": "exploration", "title": "...", "description": "A cryptic, engaging clue to find this location...", "xp_reward": 75}`;
                    } else {
                        prompt = `You are a gamified travel app quest generator.\nGenerate a DISCOVERY quest for this location. The unlocked_lore should be a fascinating historical or cultural fact about this place.\nLocation context: ${contextText}\n\nReturn ONLY a valid JSON object in this format:\n{"quest_type": "discovery", "title": "Visit ${locData.name}", "unlocked_lore": "A fascinating historical or cultural fact about this place.", "xp_reward": 50}`;
                    }
                    
                    let qData;
                    try {
                        const result = await model.generateContent(prompt);
                        let responseText = result.response.text();
                        if (responseText.startsWith("\`\`\`json")) responseText = responseText.replace(/\`\`\`json/g, "").replace(/\`\`\`/g, "").trim();
                        qData = JSON.parse(responseText);
                        // Enforce the assigned type in case Gemini overrides it
                        qData.quest_type = assignedType;
                    } catch (e) {
                        console.error(`[generateQuest] Gemini error for ${locData.name}: ${e.message}`);
                        qData = { quest_type: assignedType, title: `Explore ${locData.name}`, xp_reward: 75 };
                        if (assignedType === "trivia") {
                            qData.question = `What makes ${locData.name} an interesting place?`;
                            qData.options = ["Historical significance", "Modern architecture", "Food stalls", "Shopping"];
                            qData.correct_answer = "Historical significance";
                            qData.xp_reward = 100;
                        } else if (assignedType === "exploration") {
                            qData.description = `Find the hidden gem known as ${locData.name}. Look for clues in the surrounding area.`;
                        } else {
                            qData.unlocked_lore = `${locData.name} is a notable landmark in this area worth exploring.`;
                            qData.xp_reward = 50;
                        }
                    }
                    return { locationData: locData, questData: qData };
                });

                const results = await Promise.all(questPromises);
                generatedQuests.push(...results);
                console.log(`[generateQuest] Total quests generated: ${generatedQuests.length}`);
            }

        const clientResponses = [];
        
        // Clear out old active quests in subcollection
        const oldDocs = await db.collection("users").doc(uid).collection("active_quests").get();
        const batch = db.batch();
        oldDocs.docs.forEach(doc => batch.delete(doc.ref));
        
        // Also clear legacy root active quest if it exists
        const legacyRoot = await db.collection("active_quests").doc(uid).get();
        if (legacyRoot.exists) {
            batch.delete(legacyRoot.ref);
        }
        
        await batch.commit();

        for (const item of generatedQuests) {
            const { locationData, questData } = item;
            
            const activeQuestPayload = {
                location_id: locationData.id,
                quest_type: questData.quest_type,
                title: questData.title || "Mystery Quest",
                xp_reward: questData.xp_reward,
                timestamp: FieldValue.serverTimestamp(),
                location_lat: locationData.lat,
                location_lng: locationData.lng,
                location_name: locationData.name || "",
            };
            // Store all fields so Firestore docs are complete when re-read
            if (questData.quest_type === "trivia") {
                activeQuestPayload.correct_answer = questData.correct_answer;
                activeQuestPayload.question = questData.question || "";
                activeQuestPayload.options = questData.options || [];
            } else if (questData.quest_type === "exploration") {
                activeQuestPayload.description = questData.description || "";
            } else if (questData.quest_type === "discovery") {
                activeQuestPayload.unlocked_lore = questData.unlocked_lore || "";
            }

            await db.collection("users").doc(uid).collection("active_quests").doc(locationData.id).set(activeQuestPayload);

            const clientResp = {
                id: locationData.id,
                location_id: locationData.id,
                quest_type: questData.quest_type,
                title: questData.title,
                xp_reward: questData.xp_reward,
                location_name: locationData.name,
                coordinates: { lat: locationData.lat, lng: locationData.lng }
            };
            
            if (questData.quest_type === "trivia") {
                clientResp.question = questData.question;
                clientResp.options = questData.options;
            } else if (questData.quest_type === "exploration") {
                clientResp.description = questData.description;
            } else if (questData.quest_type === "discovery") {
                clientResp.unlocked_lore = questData.unlocked_lore;
            }
            clientResponses.push(clientResp);
        }

        return { quests: clientResponses };

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

    const { location_id, latitude, longitude, selected_answer, dev_mode } = request.data || {};
    if (!location_id || !latitude || !longitude) {
        throw new HttpsError("invalid-argument", "location_id, latitude, and longitude are required.");
    }

    try {
        const activeQuestRef = db.collection("users").doc(uid).collection("active_quests").doc(location_id);
        const userRef = db.collection("users").doc(uid);
        const today = new Date().toISOString().split('T')[0];
        const completedQuestId = `${uid}_${location_id}_${today}`;
        const completedQuestRef = db.collection("completed_quests").doc(completedQuestId);

        return await db.runTransaction(async (transaction) => {
            const activeQuestDoc = await transaction.get(activeQuestRef);
            if (!activeQuestDoc.exists) {
                 throw new HttpsError("not-found", "No active quest found for this location.");
            }

            const questData = activeQuestDoc.data();
            const realRef = activeQuestRef;

            if (questData.location_id !== location_id) {
                throw new HttpsError("invalid-argument", "Location ID does not match active quest.");
            }

            // GPS Distance check — skip if dev_mode is enabled
            if (!dev_mode) {
                const distance = getDistanceFromLatLonInM(latitude, longitude, questData.location_lat, questData.location_lng);
                if (distance > 50) {
                    throw new HttpsError("failed-precondition", `You are too far away! (${Math.round(distance)}m). You must be within 50m of the location.`);
                }
            }

            // Trivia check
            if (questData.quest_type === "trivia") {
                if (!selected_answer) {
                    throw new HttpsError("invalid-argument", "selected_answer is required for trivia quests.");
                }
                if (questData.correct_answer !== selected_answer) {
                    transaction.delete(realRef);
                    return { success: false, message: "Incorrect answer.", xpAwarded: 0 };
                }
            }

            const completedDoc = await transaction.get(completedQuestRef);
            if (completedDoc.exists) {
                transaction.delete(realRef);
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
                title: questData.title || "Unknown Quest",
                description: questData.description || questData.unlocked_lore || "",
                location_name: questData.location_name || "",
                location_lat: questData.location_lat || 0,
                location_lng: questData.location_lng || 0,
                xp_reward: questData.xp_reward || 50,
                date: today,
                timestamp: FieldValue.serverTimestamp()
            });

            transaction.delete(realRef);

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

/**
 * getDirections (HTTPS Callable)
 * Accepts origin (lat, lng) and destination (lat, lng).
 * Calls Google Directions API and returns the encoded polyline string.
 */
exports.getDirections = onCall(async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "User must be logged.");
    }

    const { originLat, originLng, destLat, destLng } = request.data || {};
    if (!originLat || !originLng || !destLat || !destLng) {
        throw new HttpsError("invalid-argument", "Origin and destination coordinates are required.");
    }

    const apiKey = process.env.PLACES_API_KEY; // Same API key for Maps & Places
    if (!apiKey) {
        throw new HttpsError("internal", "Server configuration error.");
    }

    try {
        const url = `https://maps.googleapis.com/maps/api/directions/json?origin=${originLat},${originLng}&destination=${destLat},${destLng}&mode=walking&key=${apiKey}`;
        const response = await axios.get(url);
        
        if (response.data.status !== "OK") {
            throw new Error(`Directions API error: ${response.data.status}`);
        }

        const route = response.data.routes[0];
        const polyline = route.overview_polyline.points;
        const distance = route.legs[0].distance.text;
        const duration = route.legs[0].duration.text;

        return { polyline, distance, duration };
    } catch (error) {
        console.error("Error fetching directions", error);
        throw new HttpsError("internal", "Failed to get directions.", error.message);
    }
});

/**
 * claimLoginBonus (HTTPS Callable)
 * Awards 200 XP to users when they first sign in with Google.
 * Uses a Firestore flag to prevent duplicate claims.
 */
exports.claimLoginBonus = onCall(async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "User must be logged in.");
    }
    const uid = request.auth.uid;

    try {
        const userRef = db.collection("users").doc(uid);
        const userDoc = await userRef.get();

        if (userDoc.exists && userDoc.data().login_bonus_claimed) {
            return { success: true, message: "Login bonus already claimed.", xp_awarded: 0 };
        }

        const currentXp = userDoc.exists ? (userDoc.data().xp || 0) : 0;
        const bonusXp = 200;

        await userRef.set({
            xp: currentXp + bonusXp,
            login_bonus_claimed: true,
        }, { merge: true });

        console.log(`[claimLoginBonus] Awarded ${bonusXp} XP to user ${uid}`);
        return { success: true, message: "Login bonus claimed!", xp_awarded: bonusXp };
    } catch (error) {
        console.error("claimLoginBonus error:", error);
        throw new HttpsError("internal", "Failed to claim login bonus.");
    }
});
