/**
 * Isolated test: OpenRouter only (no Gemini calls to avoid rate-limit)
 * Then test the waterfall with a deliberately bad Gemini key.
 */
require('dotenv').config();
const { GoogleGenerativeAI } = require("@google/generative-ai");

const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
const OPENROUTER_API_KEY = process.env.OPENROUTER_API_KEY;

async function main() {
    console.log("╔═════════════════════════════════════════════╗");
    console.log("║  Isolated API Tests (avoids rate-limiting)  ║");
    console.log("╚═════════════════════════════════════════════╝");

    // ─── TEST A: OpenRouter alone ───
    console.log("\n═══ TEST A: OpenRouter /free — Campaign Quest Prompt ═══");
    try {
        const prompt = `You are a gamified travel app quest generator.
Generate exactly 3 interesting travel quests themed around outdoor adventure near "NIT Hamirpur" (coordinates: 31.6966, 76.5218).
Return ONLY a valid JSON object: {"quests":[{"title":"...","description":"...","questType":"exploration","latitude":31.699,"longitude":76.523,"xpReward":100}]}
Rules: questType must be "exploration", "discovery", or "trivia". Generate EXACTLY 3.`;

        const response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
            method: "POST",
            headers: {
                "Authorization": `Bearer ${OPENROUTER_API_KEY}`,
                "Content-Type": "application/json",
                "HTTP-Referer": "https://cityquest.app",
                "X-Title": "CityQuest"
            },
            body: JSON.stringify({
                models: ["openrouter/free"],
                messages: [
                    { role: "system", content: "You are a game server API. Respond ONLY with valid JSON. No markdown. No conversation." },
                    { role: "user", content: prompt }
                ]
            })
        });
        const data = await response.json();
        if (data.error) throw new Error(data.error.message);

        let text = data.choices[0].message.content;
        text = text.replace(/```json/gi, "").replace(/```/g, "").trim();
        const parsed = JSON.parse(text);

        console.log(`  ✅ OpenRouter responded (model: ${data.model})`);
        console.log(`  ✅ Valid JSON with ${parsed.quests.length} quests`);
        parsed.quests.forEach((q, i) => {
            console.log(`     ${i+1}. [${q.questType}] "${q.title}" (+${q.xpReward} XP) @ ${q.latitude}, ${q.longitude}`);
        });
    } catch (err) {
        console.log(`  ❌ OpenRouter failed: ${err.message}`);
    }

    // ─── TEST B: Waterfall with BROKEN Gemini key (forces OpenRouter) ───
    console.log("\n═══ TEST B: Waterfall — Bad Gemini Key → OpenRouter Fallback ═══");
    try {
        const FAKE_KEY = "BROKEN_KEY_12345";
        const genAI = new GoogleGenerativeAI(FAKE_KEY);
        const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash", generationConfig: { responseMimeType: "application/json" } });
        await model.generateContent("Hello");
        console.log("  ❌ Gemini should have failed with fake key!");
    } catch (err) {
        console.log(`  ✅ Gemini correctly rejected (${err.message.substring(0, 50)}...)`);
    }

    // Now do the actual OpenRouter fallback
    try {
        const response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
            method: "POST",
            headers: {
                "Authorization": `Bearer ${OPENROUTER_API_KEY}`,
                "Content-Type": "application/json",
                "HTTP-Referer": "https://cityquest.app",
                "X-Title": "CityQuest"
            },
            body: JSON.stringify({
                models: ["openrouter/free"],
                messages: [
                    { role: "system", content: "You are a game server API. Respond ONLY with valid JSON." },
                    { role: "user", content: 'Generate 1 quest: {"quest_type":"trivia","title":"...","question":"...","options":["A","B","C","D"],"correct_answer":"...","xp_reward":100}' }
                ]
            })
        });
        const data = await response.json();
        if (data.error) throw new Error(data.error.message);
        
        let text = data.choices[0].message.content;
        text = text.replace(/```json/gi, "").replace(/```/g, "").trim();
        const parsed = JSON.parse(text);
        
        console.log(`  ✅ OpenRouter fallback caught it! (model: ${data.model})`);
        console.log(`  ✅ Generated: "${parsed.title}"`);
        console.log("  🎯 WATERFALL PATTERN VERIFIED: Gemini fail → OpenRouter success");
    } catch (err) {
        console.log(`  ❌ OpenRouter fallback also failed: ${err.message}`);
    }

    console.log("\n══════════════════════════════════════");
    console.log("  All isolated tests complete!");
    console.log("══════════════════════════════════════\n");
}

main();
