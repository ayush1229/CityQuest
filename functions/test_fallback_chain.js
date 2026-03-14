/**
 * Test Suite: 3-Tier AI Fallback Chain
 * Tests Gemini, OpenRouter, and the full generateCampaignQuests flow.
 * 
 * Usage: node test_fallback_chain.js
 */
require('dotenv').config();
const { GoogleGenerativeAI } = require("@google/generative-ai");

const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
const OPENROUTER_API_KEY = process.env.OPENROUTER_API_KEY;

let passed = 0;
let failed = 0;

function logResult(testName, success, detail) {
    if (success) {
        console.log(`  ✅ PASS: ${testName}`);
        passed++;
    } else {
        console.log(`  ❌ FAIL: ${testName} — ${detail}`);
        failed++;
    }
}

// ─── TEST 1: Gemini Direct ───
async function testGemini() {
    console.log("\n═══ TEST 1: Gemini API Direct ═══");
    if (!GEMINI_API_KEY) {
        logResult("Gemini API Key exists", false, "GEMINI_API_KEY not in .env");
        return;
    }
    logResult("Gemini API Key exists", true);

    try {
        const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
        const model = genAI.getGenerativeModel({ 
            model: "gemini-2.5-flash", 
            generationConfig: { responseMimeType: "application/json" } 
        });

        const prompt = `Generate 1 trivia quest about NIT Hamirpur. Return ONLY valid JSON:
{"quest_type":"trivia","title":"...","question":"...","options":["A","B","C","D"],"correct_answer":"...","xp_reward":100}`;

        const result = await model.generateContent(prompt);
        let text = result.response.text();
        if (text.startsWith("```json")) text = text.replace(/```json/g, "").replace(/```/g, "").trim();
        
        logResult("Gemini responded", true);

        const parsed = JSON.parse(text);
        logResult("Response is valid JSON", true);
        logResult("Has quest_type field", !!parsed.quest_type, `Got: ${JSON.stringify(parsed).substring(0, 80)}...`);
        logResult("Has title field", !!parsed.title, "Missing title");
        console.log(`  📋 Generated: "${parsed.title}"`);
    } catch (err) {
        logResult("Gemini call succeeded", false, err.message);
    }
}

// ─── TEST 2: OpenRouter Direct ───
async function testOpenRouter() {
    console.log("\n═══ TEST 2: OpenRouter API Direct ═══");
    if (!OPENROUTER_API_KEY) {
        logResult("OpenRouter API Key exists", false, "OPENROUTER_API_KEY not in .env");
        return;
    }
    logResult("OpenRouter API Key exists", true);

    try {
        const systemPrompt = `You are a game server API. Respond ONLY with valid JSON. No markdown. No conversation.`;
        const userPrompt = `Generate 1 discovery quest near NIT Hamirpur. Return JSON: {"quest_type":"discovery","title":"...","unlocked_lore":"...","xp_reward":50}`;

        const response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
            method: "POST",
            headers: {
                "Authorization": `Bearer ${OPENROUTER_API_KEY}`,
                "Content-Type": "application/json",
                "HTTP-Referer": "https://cityquest.app",
                "X-Title": "CityQuest Test"
            },
            body: JSON.stringify({
                models: ["openrouter/free"],
                messages: [
                    { role: "system", content: systemPrompt },
                    { role: "user", content: userPrompt }
                ]
            })
        });

        const data = await response.json();
        if (data.error) {
            logResult("OpenRouter responded", false, data.error.message);
            return;
        }

        logResult("OpenRouter responded", true);
        logResult(`Model used: ${data.model}`, true);

        let text = data.choices[0].message.content;
        text = text.replace(/```json/gi, "").replace(/```/g, "").trim();

        const parsed = JSON.parse(text);
        logResult("Response is valid JSON", true);
        logResult("Has quest_type field", !!parsed.quest_type, `Got: ${text.substring(0, 80)}`);
        console.log(`  📋 Generated: "${parsed.title}"`);
    } catch (err) {
        logResult("OpenRouter call succeeded", false, err.message);
    }
}

// ─── TEST 3: Full generateWithAI waterfall ───
async function testGenerateWithAI() {
    console.log("\n═══ TEST 3: generateWithAI() Waterfall ═══");
    
    // Import the exact same function from index.js
    async function generateWithAI(prompt, geminiApiKey) {
        // Tier 1: Gemini
        try {
            const genAI = new GoogleGenerativeAI(geminiApiKey);
            const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash", generationConfig: { responseMimeType: "application/json" } });
            const result = await model.generateContent(prompt);
            let text = result.response.text();
            if (text.startsWith("```json")) text = text.replace(/```json/g, "").replace(/```/g, "").trim();
            console.log("  [Tier 1] ✅ Gemini responded.");
            return { text, source: "Gemini" };
        } catch (err) {
            console.log(`  [Tier 1] ⚠️ Gemini failed: ${err.message}`);
        }
        // Tier 2: OpenRouter
        if (OPENROUTER_API_KEY) {
            try {
                const sysPrompt = `You are a game server API. Respond ONLY with valid JSON. No markdown.`;
                const orResp = await fetch("https://openrouter.ai/api/v1/chat/completions", {
                    method: "POST",
                    headers: { "Authorization": `Bearer ${OPENROUTER_API_KEY}`, "Content-Type": "application/json", "HTTP-Referer": "https://cityquest.app", "X-Title": "CityQuest" },
                    body: JSON.stringify({ models: ["openrouter/free"], messages: [{ role: "system", content: sysPrompt }, { role: "user", content: prompt }] })
                });
                const orData = await orResp.json();
                if (orData.error) throw new Error(orData.error.message);
                let text = orData.choices[0].message.content;
                text = text.replace(/```json/gi, "").replace(/```/g, "").trim();
                console.log(`  [Tier 2] ✅ OpenRouter responded (${orData.model}).`);
                return { text, source: "OpenRouter" };
            } catch (err) {
                console.log(`  [Tier 2] ⚠️ OpenRouter failed: ${err.message}`);
            }
        }
        // Tier 3
        console.log("  [Tier 3] 🔴 All AI failed. Returning null.");
        return null;
    }

    const prompt = `Generate 1 exploration quest near Shimla. Return ONLY JSON: {"quest_type":"exploration","title":"...","description":"A cryptic clue...","xp_reward":75}`;
    const result = await generateWithAI(prompt, GEMINI_API_KEY);
    
    if (result) {
        logResult(`Waterfall succeeded (source: ${result.source})`, true);
        try {
            const parsed = JSON.parse(result.text);
            logResult("Waterfall output is valid JSON", true);
            console.log(`  📋 Generated: "${parsed.title}"`);
        } catch (e) {
            logResult("Waterfall output is valid JSON", false, e.message);
        }
    } else {
        logResult("Waterfall returned a result", false, "All tiers failed");
    }
}

// ─── TEST 4: Campaign Quest Generation (simulates generateCampaignQuests) ───
async function testCampaignQuests() {
    console.log("\n═══ TEST 4: Campaign Quest Generation (Oracle) ═══");

    const classType = "adventurer";
    const lat = 31.6966;
    const lng = 76.5218;
    const area = "NIT Hamirpur";
    const themeDesc = "outdoor adventure spots: hiking trails, parks, scenic viewpoints, waterfalls, campsites";

    const prompt = `You are a gamified travel app quest generator.
Generate exactly 3 interesting travel quests themed around ${themeDesc} near "${area}" (coordinates: ${lat}, ${lng}).

Return ONLY a valid JSON object in this exact format:
{
  "quests": [
    {
      "title": "Quest Title",
      "description": "A short, engaging description of this destination.",
      "questType": "exploration",
      "latitude": ${lat + 0.003},
      "longitude": ${lng + 0.002},
      "xpReward": 100
    }
  ]
}

Rules:
- Generate EXACTLY 3 quests.
- questType must be one of: "exploration", "discovery", "trivia".
- Latitude/longitude must be realistic coordinates near the given location.
- xpReward must be between 50 and 150.
- Titles should be creative and thematic.`;

    try {
        const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
        const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash", generationConfig: { responseMimeType: "application/json" } });
        const result = await model.generateContent(prompt);
        let text = result.response.text();
        if (text.startsWith("```json")) text = text.replace(/```json/g, "").replace(/```/g, "").trim();

        const parsed = JSON.parse(text);
        logResult("Campaign response is valid JSON", true);
        logResult("Has 'quests' array", Array.isArray(parsed.quests), `Got: ${typeof parsed.quests}`);
        logResult(`Generated ${parsed.quests?.length || 0} quests (expected 3)`, parsed.quests?.length === 3, `Got ${parsed.quests?.length}`);

        if (parsed.quests && parsed.quests.length > 0) {
            parsed.quests.forEach((q, i) => {
                const hasRequired = q.title && q.questType && q.latitude && q.longitude && q.xpReward;
                logResult(`Quest ${i+1} has all required fields`, !!hasRequired, `Missing fields in: ${JSON.stringify(q).substring(0,60)}`);
                const validType = ["exploration", "discovery", "trivia"].includes(q.questType);
                logResult(`Quest ${i+1} type is valid (${q.questType})`, validType, `Invalid type: ${q.questType}`);
            });
            console.log("\n  📋 Generated Quests:");
            parsed.quests.forEach((q, i) => {
                console.log(`     ${i+1}. [${q.questType}] "${q.title}" (+${q.xpReward} XP) @ ${q.latitude.toFixed(4)}, ${q.longitude.toFixed(4)}`);
            });
        }
    } catch (err) {
        logResult("Campaign quest generation", false, err.message);
    }
}

// ─── RUN ALL TESTS ───
async function runAllTests() {
    console.log("╔══════════════════════════════════════════════╗");
    console.log("║  CityQuest AI Fallback Chain — Test Suite    ║");
    console.log("╚══════════════════════════════════════════════╝");

    await testGemini();
    await testOpenRouter();
    await testGenerateWithAI();
    await testCampaignQuests();

    console.log("\n══════════════════════════════════════");
    console.log(`  Results: ${passed} passed, ${failed} failed`);
    console.log("══════════════════════════════════════\n");
}

runAllTests();
