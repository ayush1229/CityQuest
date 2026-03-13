const { GoogleGenerativeAI } = require("@google/generative-ai");
const fs = require("fs");
const envFile = fs.readFileSync(".env", "utf8");
let apiKey = "";
envFile.split("\n").forEach(line => {
    if (line.startsWith("GEMINI_API_KEY")) {
        apiKey = line.split("=")[1].replace(/"/g, "").trim();
    }
});

async function run() {
    try {
        const genAI = new GoogleGenerativeAI(apiKey);

        const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });
        const result = await model.generateContent("Give me a one sentence trivia fact about Paris.");
        console.log("Success:", result.response.text());
    } catch (e) {
        console.error("Error Message:", e.message);
    }
}
run();
