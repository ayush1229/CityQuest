require('dotenv').config();

const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
const OPENROUTER_API_KEY = process.env.OPENROUTER_API_KEY;

// ─── 1. PRIMARY: DIRECT GOOGLE AI STUDIO (GEMINI) ─────────────────
async function fetchFromGemini(prompt) {
    console.log("🟢 Attempting Primary: Google Gemini (Direct API)...");
    
    if (!GEMINI_API_KEY) {
        throw new Error("GEMINI_API_KEY is missing from .env!");
    }

    // 🛑 CHANGE TO 'true' TO TEST THE FALLBACK TO OPENROUTER
    const simulateGeminiFailure = false; 
    if (simulateGeminiFailure) {
        throw new Error("Simulated Gemini Failure");
    }

    // Using the native REST API for Gemini 2.5 Flash
    const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${GEMINI_API_KEY}`;
    
    const response = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            contents: [{ parts: [{ text: prompt }] }],
            // Optional: force JSON output to make parsing easier later!
            generationConfig: { responseMimeType: "application/json" }
        })
    });

    const data = await response.json();

    if (data.error) {
        throw new Error(`Gemini API Error: ${data.error.message}`);
    }

    return data.candidates[0].content.parts[0].text;
}

// ─── 2. SECONDARY: OPENROUTER API FALLBACK ────────────────────────
async function fetchFromOpenRouter(prompt) {
    console.log("🟡 Attempting Secondary: OpenRouter Fallback...");
    
    if (!OPENROUTER_API_KEY) {
        throw new Error("OPENROUTER_API_KEY is missing from .env!");
    }

    // 🛑 CHANGE TO 'true' TO TEST THE HARDCODED FALLBACK
    const simulateOpenRouterFailure = false;
    if (simulateOpenRouterFailure) {
        throw new Error("Simulated OpenRouter Failure");
    }

    const response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
        method: "POST",
        headers: {
            "Authorization": `Bearer ${OPENROUTER_API_KEY}`,
            "Content-Type": "application/json"
        },
        body: JSON.stringify({
            // Updated to valid OpenRouter Free models
            models: [
                "google/gemini-2.0-flash-lite-preview-02-05:free", 
                "meta-llama/llama-3.1-8b-instruct:free" 
            ],
            messages: [{ role: "user", content: prompt }]
        })
    });

    const data = await response.json();

    if (data.error) {
        throw new Error(`OpenRouter Error: ${data.error.message}`);
    }

    return data.choices[0].message.content;
}

// ─── 3. TERTIARY: HARDCODED EMERGENCY FALLBACK ────────────────────
function getHardcodedQuests() {
    console.log("🔴 Attempting Tertiary: Hardcoded Emergency Fallback...");
    
    return JSON.stringify([
        {
            "id": "emergency_quest_1",
            "title": "The Hidden Library",
            "description": "Find the oldest book in the central library.",
            "questType": "discovery",
            "latitude": 31.6966, 
            "longitude": 76.5218,
            "xpReward": 50
        }
    ]);
}

// ─── THE WATERFALL EXECUTOR ───────────────────────────────────────
async function generateAIQuests(prompt) {
    try {
        const result = await fetchFromGemini(prompt);
        console.log("\n✅ SUCCESS (Source: Direct Gemini):");
        console.log(result);
        return result;

    } catch (geminiError) {
        console.error(`\n⚠️ Gemini Failed: ${geminiError.message}`);
        
        try {
            const result = await fetchFromOpenRouter(prompt);
            console.log("\n✅ SUCCESS (Source: OpenRouter):");
            console.log(result);
            return result;

        } catch (openRouterError) {
            console.error(`\n⚠️ OpenRouter Failed: ${openRouterError.message}`);
            
            const result = getHardcodedQuests();
            console.log("\n✅ SUCCESS (Source: Hardcoded Fallback):");
            console.log(result);
            return result;
        }
    }
}

// Run the test
// Requesting JSON array format so it easily drops into your Flutter models
generateAIQuests("Generate 1 local quest for a hackathon demo near NIT Hamirpur. Return ONLY a valid JSON array.");