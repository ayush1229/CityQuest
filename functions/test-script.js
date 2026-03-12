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
                    set: async () => {}, get: async () => ({ 
                        exists: true, 
                        data: () => ({
                            location_id: "loc1", 
                            location_lat: 48.8584,
                            location_lng: 2.2945,
                            quest_type: "trivia",
                            correct_answer: "Option A",
                            xp_reward: 100
                        }) 
                    }), 
                    delete: async () => {} 
                })
            }),
            runTransaction: async (cb) => cb({ 
                get: async(ref)=>{
                    if(ref.id) return { exists: false };
                    return { 
                        exists: true,
                        data: () => ({
                            location_id: "loc1", 
                            location_lat: 48.8584,
                            location_lng: 2.2945,
                            quest_type: "trivia",
                            correct_answer: "test",
                            xp_reward: 100
                        })
                    }
                }, 
                set: ()=>{}, update: ()=>{}, delete: ()=>{} 
            })
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
        const runFn = myFunctions.completeQuest.run || myFunctions.completeQuest;
        // Test with exact coordinates to pass 50m check
        const result = await runFn({ 
            auth: { uid: 'user' }, 
            data: { location_id: "loc1", latitude: 48.8584, longitude: 2.2945, selected_answer: "test" } 
        });
        logs.push({ name: "completeQuest", status: "success", data: result });
    } catch (e) {
        logs.push({ name: "completeQuest", status: "error", error: e.message || e });
    }
    
    // Test too far away
    try {
        const runFn = myFunctions.completeQuest.run || myFunctions.completeQuest;
        // Test with wrong coordinates to fail 50m check
        const result = await runFn({ 
            auth: { uid: 'user' }, 
            data: { location_id: "loc1", latitude: 48.8580, longitude: 2.2945, selected_answer: "test" } 
        });
        logs.push({ name: "completeQuest_far", status: "success", data: result });
    } catch (e) {
        logs.push({ name: "completeQuest_far", status: "error", error: e.message || e });
    }

    fs.writeFileSync('test-output.json', JSON.stringify(logs, null, 2));
}

testLocally();
