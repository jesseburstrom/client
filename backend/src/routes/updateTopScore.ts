//import jwt from "jsonwebtoken";
import { getDbConnection } from "../db";

export const updateTopScore = {
  path: "/UpdateTopScore" ,
  method: "post",
  handler: async (req, res) => {
    const db = getDbConnection("top-scores");

    var results = [];
    try {
      switch (req.body.type) {
        case "Ordinary": {
          await db
            .collection("ordinary")
            .insertOne({ name: req.body.name, score: req.body.score });
          results = await db
            .collection("ordinary")
            .find({}, { _id: 0 })
            .sort({ score: -1 })
            .toArray();
          break;
        }

        case "Mini": {
          await db
            .collection("mini")
            .insertOne({ name: req.body.name, score: req.body.score });
          results = await db
            .collection("mini")
            .find({}, { _id: 0 })
            .sort({ score: -1 })
            .toArray();
          break;
        }

        case "Maxi": {
          await db
            .collection("maxi")
            .insertOne({ name: req.body.name, score: req.body.score });
          results = await db
            .collection("maxi")
            .find({}, { _id: 0 })
            .sort({ score: -1 })
            .toArray();
          break;
        }

        case "MaxiR3": {
          await db
            .collection("maxiR3")
            .insertOne({ name: req.body.name, score: req.body.score });
          results = await db
            .collection("maxiR3")
            .find({}, { _id: 0 })
            .sort({ score: -1 })
            .toArray();
          break;
        }

        case "MaxiE3": {
          await db
            .collection("maxiE3")
            .insertOne({ name: req.body.name, score: req.body.score });
          results = await db
            .collection("maxiE3")
            .find({}, { _id: 0 })
            .sort({ score: -1 })
            .toArray();
          break;
        }

        case "MaxiRE3": {
          await db
            .collection("maxiRE3")
            .insertOne({ name: req.body.name, score: req.body.score });
          results = await db
            .collection("maxiRE3")
            .find({}, { _id: 0 })
            .sort({ score: -1 })
            .toArray();
          break;
        }
      }
      res.status(200).json(results);
    } catch (e) {
      console.log(e);
      res.sendStatus(500);
    }
  },
};
