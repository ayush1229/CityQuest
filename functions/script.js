const fs = require('fs');
require('dotenv').config(); 

const API_KEY = process.env.PLACES_API_KEY; 
const LAT = 31.6966; 
const LNG = 76.5218;
const RADIUS = 10000.0; // 10km

if (!API_KEY) {
    console.error("❌ API Key not found!");
    process.exit(1);
}

// We loop through these specific categories to bypass the 20-item limit.
// It will pull up to 20 places FOR EACH category!
const targetCategories = [
    'hospital', 'restaurant', 'cafe', 'hindu_temple', 
    'school', 'university', 'supermarket', 'lodging'
];

async function fetchPlacesAndTags() {
    let allPlaces = [];

    console.log("Starting Category Deep-Scan...");

    for (const category of targetCategories) {
        console.log(`Scanning for ${category}s...`);
        
        const requestBody = {
            includedTypes: [category],
            maxResultCount: 20, // Max allowed per category
            locationRestriction: {
                circle: { center: { latitude: LAT, longitude: LNG }, radius: RADIUS }
            }
        };

        try {
            const response = await fetch('https://places.googleapis.com/v1/places:searchNearby', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'X-Goog-Api-Key': API_KEY,
                    // We need BOTH the name and the tags now
                    'X-Goog-FieldMask': 'places.displayName,places.types' 
                },
                body: JSON.stringify(requestBody)
            });

            const data = await response.json();

            if (data.places) {
                data.places.forEach(place => {
                    const name = place.displayName ? place.displayName.text : 'Unknown Place';
                    const tags = place.types ? place.types.join(', ') : 'no_tags';
                    
                    // Ensure we don't add the exact same place twice if it fits multiple categories
                    if (!allPlaces.some(p => p.name === name)) {
                        allPlaces.push({ name, tags });
                    }
                });
            }
        } catch (error) {
            console.error(`Failed to fetch ${category}:`, error);
        }
    }

    // Format the output into a readable list
    let outputText = `Places found within 10km of NIT Hamirpur:\n==========================================\n\n`;
    allPlaces.forEach(p => {
        outputText += `📍 ${p.name}\n   Tags: [${p.tags}]\n\n`;
    });

    fs.writeFileSync('places_mapped.txt', outputText);
    console.log(`\n✅ Success! Saved ${allPlaces.length} distinct places and their tags to 'places_mapped.txt'`);
}

fetchPlacesAndTags();