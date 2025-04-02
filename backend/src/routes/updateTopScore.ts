//import jwt from "jsonwebtoken";
import { getDbConnection } from "../db";
// --- Simplification: Import TopScoreService to trigger broadcast ---
// Assuming TopScoreService is initialized and accessible, e.g., via dependency injection or a singleton pattern
// If not easily accessible, this route would *not* broadcast updates. The service-based update is preferred.
// For now, we'll comment this out as direct service access isn't set up here.
// import { topScoreServiceInstance } from '../server'; // Example of how it might be accessed

export const updateTopScore = {
  path: "/UpdateTopScore" ,
  method: "post",
  handler: async (req, res) => {
    const db = getDbConnection("top-scores");

    var results = [];
    try {

      // --- MODIFIED: Validate game type ---
      const requestedType = req.body.type as string;
      const allowedTypes = ['Ordinary', 'Maxi']; // Only allow these
      if (!allowedTypes.includes(requestedType)) {
          console.warn(`[updateTopScore Route] Invalid game type requested: ${requestedType}`);
          return res.status(400).json({ message: `Invalid game type: ${requestedType}` });
      }
      // --- End Modification ---

    // Simplified logic
    let collectionName = '';
    if (requestedType === 'Ordinary') {
        collectionName = 'ordinary';
    } else if (requestedType === 'Maxi') {
        collectionName = 'maxi';
    }
    // No else needed due to validation above

    const collection = db.collection(collectionName);

    await collection.insertOne({ name: req.body.name, score: req.body.score });
    results = await collection
        .find({}, { projection: { _id: 0 } })
        .sort({ score: -1 })
        .toArray();

      // Broadcasting handled by TopScoreService ideally
      res.status(200).json(results);
    } catch (e) {
      console.log(e);
      res.sendStatus(500);
    }
  },
};
