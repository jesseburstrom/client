// backend/src/routes/getTopScores.ts
import { getDbConnection } from "../db";

export const getTopScores = {
  path: "/GetTopScores",
  method: "get",
  handler: async (req, res) => {
    // --- Suggestion: Add logging at the very start ---
    console.log(`[ROUTE /GetTopScores] Handling request for type: ${req.query.type}`);
    // -------------------------------------------------
    let db; // Define db outside try block to check connection status
    try {
        // --- Potential Failure Point 1: Getting DB Connection ---
        db = getDbConnection("top-scores");
        console.log("[ROUTE /GetTopScores] Acquired DB connection for 'top-scores'.");
        // ---------------------------------------------------------

        const requestedType = req.query.type as string;
        const allowedTypes = ['Ordinary', 'Maxi'];
        if (!allowedTypes.includes(requestedType)) {
            console.warn(`[getTopScores Route] Invalid game type requested: ${requestedType}`);
            return res.status(400).json({ message: `Invalid game type: ${requestedType}` });
        }

        let collectionName = '';
        if (requestedType === 'Ordinary') {
            collectionName = 'ordinary';
        } else if (requestedType === 'Maxi') {
            collectionName = 'maxi';
        }
        console.log(`[ROUTE /GetTopScores] Determined collection name: ${collectionName}`);

        // --- Potential Failure Point 2: Database Query ---
        console.log(`[ROUTE /GetTopScores] Querying collection '${collectionName}'...`);
        const results = await db
            .collection(collectionName)
            .find({}, { projection: { _id: 0 } })
            .sort({ score: -1 })
            .toArray();
        console.log(`[ROUTE /GetTopScores] Query successful, found ${results.length} results.`);
        // ------------------------------------------------

        // --- Success Case ---
        res.status(200).json(results);
        console.log(`[ROUTE /GetTopScores] Sent 200 response with results.`);
        // --------------------

    } catch (e) {
        // --- Error Handling ---
        // Log the error with more context
        console.error("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
        console.error(`[ROUTE /GetTopScores] !!! CATCH BLOCK ERROR for type ${req.query.type}:`, e);
        console.error("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");

        // Check if db connection was even established
        if (!db) {
            console.error("[ROUTE /GetTopScores] Error likely occurred during getDbConnection.");
        }

        // Send a 500 Internal Server Error response if headers haven't been sent yet
        if (!res.headersSent) {
             // Use sendStatus(500) or status(500).json(...)
             // Using json provides a slightly more informative response body
             res.status(500).json({ error: 'Failed to retrieve top scores due to internal server error.' });
             console.log("[ROUTE /GetTopScores] Sent 500 response due to caught error.");
        } else {
            console.error("[ROUTE /GetTopScores] Headers already sent, could not send 500 response.");
        }
        // Note: Even if we send 500 here, Nginx might still show 502 if the process handling
        // the request crashed badly or timed out before this catch block completed.
        // ----------------------
    }
  },
};
// //import jwt from "jsonwebtoken";
// import { getDbConnection } from "../db";
//
// export const getTopScores = {
//   path: "/GetTopScores",
//   method: "get",
//   handler: async (req, res) => {
//     const db = getDbConnection("top-scores");
//     var results;
//     try {
//         // --- MODIFIED: Validate game type ---
//         const requestedType = req.query.type as string;
//         const allowedTypes = ['Ordinary', 'Maxi']; // Only allow these
//         if (!allowedTypes.includes(requestedType)) {
//             console.warn(`[getTopScores Route] Invalid game type requested: ${requestedType}`);
//             return res.status(400).json({ message: `Invalid game type: ${requestedType}` });
//         }
//         // --- End Modification ---
//
//         // Simplified switch or use if/else
//         let collectionName = '';
//         if (requestedType === 'Ordinary') {
//             collectionName = 'ordinary';
//         } else if (requestedType === 'Maxi') {
//             collectionName = 'maxi';
//         }
//         // No else needed due to validation above
//
//         console.log(`getting ${collectionName} game topscores`);
//         results = await db
//             .collection(collectionName)
//             .find({}, { projection: { _id: 0 } })
//             .sort({ score: -1 })
//             .toArray();
//
//         res.status(200).json(results);
//     } catch (e) {
//       console.log(e);
//       res.sendStatus(500);
//     }
//   },
// };
