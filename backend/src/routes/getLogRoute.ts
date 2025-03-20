import * as jwt from "jsonwebtoken";
import { getDbConnection } from "../db";

export const getLogRoute = {
  path: "/api/getLog/:userId",
  method: "get",
  handler: async (req, res) => {
    const { authorization } = req.headers;
    const { userId } = req.params;

    console.log("in getLogRoute", userId);
    if (!authorization) {
      console.log("No auth");
      return res.status(401).json({ message: "No authorization header sent" });
    }

    const token = authorization.split(" ")[1];

    jwt.verify(token, process.env.JWT_SECRET, async (err, decoded) => {
      console.log("token ver");
      if (err)
        return res.status(401).json({ message: "Unable to verify token" });
      console.log("token verified");
      const { id } = decoded;

      if (id !== userId) {
        console.log("id mismatch");
        return res
          .status(403)
          .json({ message: "Not allowed to update that user's data" });
      }

      const db = getDbConnection("react-auth-db");

      const result = await db.collection("logs").find({ insertedId: userId });
      console.log("result ", result);
      res.status(200).json(result.value);
    });
  },
};
