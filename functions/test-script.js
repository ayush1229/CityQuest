const fs = require('fs');
const Module = require('module');
const originalRequire = Module.prototype.require;

try {
    const envFile = fs.readFileSync('.env', 'utf8');
    envFile.split('\n').forEach(line => {
        if (line.includes('=')) {
            const parts = line.split('=');
            process.env[parts[0].trim()] = parts.slice(1).join('=').replace(/^"|"$/g, '').trim();
        }
    });
} catch (e) {}

Module.prototype.require = function() {
    if (arguments[0] === 'firebase-admin/app') return { initializeApp: () => {} };
    if (arguments[0] === 'firebase-admin/firestore') return {
        getFirestore: () => ({
            collection: () => ({
                doc: () => ({
                    set: async () => {}, get: async () => ({ exists: false }), delete: async () => {} 
                })
            }),
            runTransaction: async (cb) => cb({ get: async()=>({exists:false}), set: ()=>{}, update: ()=>{}, delete: ()=>{} })
        }),
        FieldValue: { serverTimestamp: () => "timestamp" }
    };
    return originalRequire.apply(this, arguments);
};

const myFunctions = require('./index.js');

async function testLocally() {
    const logs = [];
    try {
        const runFn = myFunctions.generateQuest.run || myFunctions.generateQuest;
        const result = await runFn({ auth: { uid: 'user' }, data: { latitude: 48.8584, longitude: 2.2945 } });
        logs.push({ name: "generateQuest", status: "success", data: result });
    } catch (e) {
        logs.push({ name: "generateQuest", status: "error", error: e.message || e });
    }

    try {
        const runFn = myFunctions.submitAnswer.run || myFunctions.submitAnswer;
        const result = await runFn({ auth: { uid: 'user' }, data: { location_id: "loc1", selected_answer: "test" } });
        logs.push({ name: "submitAnswer", status: "success", data: result });
    } catch (e) {
        logs.push({ name: "submitAnswer", status: "error", error: e.message || e });
    }

    fs.writeFileSync('test-output.json', JSON.stringify(logs, null, 2));
}

testLocally();
