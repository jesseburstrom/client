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

      // --- Simplification: Validate game type ---
    const requestedType = req.body.type as string;
    if (!['Ordinary', 'Mini', 'Maxi'].includes(requestedType)) {
        console.warn(`[updateTopScore Route] Invalid game type requested: ${requestedType}`);
        return res.status(400).json({ message: `Invalid game type: ${requestedType}` });
    }
    // --- End Simplification ---

    const collectionName = requestedType.charAt(0).toLowerCase() + requestedType.slice(1);
    const collection = db.collection(collectionName);

    await collection.insertOne({ name: req.body.name, score: req.body.score });
    results = await collection
        .find({}, { projection: { _id: 0 } })
        .sort({ score: -1 })
        .toArray();

      // --- Simplification: Broadcasting should ideally happen via the Service ---
        // If topScoreServiceInstance is available:
        // await topScoreServiceInstance.broadcastTopScores();
        // Otherwise, the broadcast won't happen via this HTTP route. Clients relying
        // on the WebSocket update ('onTopScoresUpdate') are preferred.
      res.status(200).json(results);
    } catch (e) {
      console.log(e);
      res.sendStatus(500);
    }
  },
};
