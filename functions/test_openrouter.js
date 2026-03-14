require('dotenv').config();

const OPENROUTER_API_KEY = process.env.OPENROUTER_API_KEY;

async function testOpenRouterJSON() {
    console.log("🟡 Pinging OpenRouter API for Strict JSON...");
    
    if (!OPENROUTER_API_KEY) {
        console.error("❌ ERROR: OPENROUTER_API_KEY is missing from your .env file!");
        return;
    }

    // 1. The strict rules for the AI
    const systemPrompt = `You are a game server API. You must respond ONLY with valid JSON. 
Do not include markdown formatting like \`\`\`json. Do not include any conversational text. 
Your response must be a single JSON object containing a "quests" array.
Use this exact schema:
{
  "quests": [
    {
      "id": "unique_string",
      "title": "Quest Title",
      "description": "Short description of the quest.",
      "questType": "discovery", // Must be 'discovery', 'exploration', or 'trivia'
      "latitude": 31.6966, // Must be a float close to the user
      "longitude": 76.5218, // Must be a float close to the user
      "xpReward": 50 // Integer between 10 and 100
    }
  ]
}`;

    // 2. The dynamic user request
    const userPrompt = "Generate 2 interesting local side quests near NIT Hamirpur. Make one a 'trivia' quest and one a 'discovery' quest.";

    try {
        const response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
            method: "POST",
            headers: {
                "Authorization": `Bearer ${OPENROUTER_API_KEY}`,
                "Content-Type": "application/json",
                "HTTP-Referer": "https://cityquest.app", 
                "X-Title": "CityQuest Hackathon"
            },
            body: JSON.stringify({
                // Using Google's free Flash Lite first because it is lightning fast and great at JSON, 
                // then falling back to the auto-router if Google is busy.
                models: [
                    "openrouter/free" 
                ],
                messages: [
                    { role: "system", content: systemPrompt },
                    { role: "user", content: userPrompt }
                ]
                // ❌ REMOVED response_format: { type: "json_object" } 
                // Free models often crash when forced into strict API JSON mode!
            })
        });

        const data = await response.json();

        if (data.error) {
            console.error("\n❌ OPENROUTER REJECTED THE REQUEST:");
            console.error(data.error);
            return;
        }

        let rawContent = data.choices[0].message.content;

        // 3. The Safety Net: Strip markdown formatting just in case the AI ignored instructions
        let cleanJsonString = rawContent.replace(/```json/gi, '').replace(/```/g, '').trim();

        console.log("\n✅ RAW AI OUTPUT CLEANED:");
        console.log(cleanJsonString);

        // 4. Prove it works by parsing it into a real JavaScript object
        try {
            const parsedData = JSON.parse(cleanJsonString);
            console.log("\n🎉 SUCCESS! IT PARSED PERFECTLY!");
            console.log(`Received ${parsedData.quests.length} quests.`);
            console.log("First Quest Title:", parsedData.quests[0].title);
        } catch (parseError) {
            console.error("\n❌ JSON PARSE FAILED. The AI output invalid formatting.");
            console.error(parseError.message);
        }

    } catch (error) {
        console.error("\n❌ NETWORK OR FETCH ERROR:");
        console.error(error.message);
    }
}

testOpenRouterJSON();