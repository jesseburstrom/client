//import jwt from "jsonwebtoken";
import { getDbConnection } from "../db";

export const getTopScores = {
  path: "/GetTopScores",
  method: "get",
  handler: async (req, res) => {
    const db = getDbConnection("top-scores");
    var results;
    try {
        // --- MODIFIED: Validate game type ---
        const requestedType = req.query.type as string;
        const allowedTypes = ['Ordinary', 'Maxi']; // Only allow these
        if (!allowedTypes.includes(requestedType)) {
            console.warn(`[getTopScores Route] Invalid game type requested: ${requestedType}`);
            return res.status(400).json({ message: `Invalid game type: ${requestedType}` });
        }
        // --- End Modification ---

        // Simplified switch or use if/else
        let collectionName = '';
        if (requestedType === 'Ordinary') {
            collectionName = 'ordinary';
        } else if (requestedType === 'Maxi') {
            collectionName = 'maxi';
        }
        // No else needed due to validation above

        console.log(`getting ${collectionName} game topscores`);
        results = await db
            .collection(collectionName)
            .find({}, { projection: { _id: 0 } })
            .sort({ score: -1 })
            .toArray();

        res.status(200).json(results);
    } catch (e) {
      console.log(e);
      res.sendStatus(500);
    }
  },
};
