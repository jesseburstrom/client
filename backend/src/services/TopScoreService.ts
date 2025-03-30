// backend/src/services/TopScoreService.ts
import { Collection, Db } from 'mongodb';
import { getDbConnection } from '../db';

const DB_NAME = 'top-scores';

interface TopScoreEntry {
  name: string;
  score: number;
}

export class TopScoreService {
  private getDb(): Db {
    return getDbConnection(DB_NAME);
  }

  private getCollection(gameType: string): Collection<TopScoreEntry> {
    const db = this.getDb();
    // Normalize collection name (e.g., MaxiR3 -> maxiR3)
    const collectionName = gameType.charAt(0).toLowerCase() + gameType.slice(1);
    return db.collection<TopScoreEntry>(collectionName);
  }

  /**
   * Gets the top scores for a given game type.
   * @param gameType - The type of game (e.g., "Ordinary", "MaxiR3").
   * @param limit - The maximum number of scores to return.
   * @returns An array of top score entries.
   */
  async getTopScores(gameType: string, limit: number = 20): Promise<TopScoreEntry[]> {
    try {
      const collection = this.getCollection(gameType);
      const results = await collection
        .find({}, { projection: { _id: 0 } }) // Exclude the _id field
        .sort({ score: -1 }) // Sort by score descending
        .limit(limit) // Limit the results
        .toArray();
      console.log(`📊 [TopScoreService] Fetched ${results.length} top scores for ${gameType}`);
      return results;
    } catch (error) {
      console.error(`❌ [TopScoreService] Error fetching top scores for ${gameType}:`, error);
      return []; // Return empty array on error
    }
  }

  /**
   * Attempts to add a new score to the top scores list if it qualifies.
   * Currently, it just adds the score; filtering/limiting logic might be needed.
   * @param gameType - The type of game.
   * @param name - The player's name.
   * @param score - The player's score.
   * @returns True if the score was inserted, false otherwise.
   */
  async updateTopScore(gameType: string, name: string, score: number): Promise<boolean> {
     // Basic validation
     if (!name || typeof score !== 'number' || !gameType) {
       console.warn(`❌ [TopScoreService] Invalid data for updateTopScore: name=${name}, score=${score}, gameType=${gameType}`);
       return false;
     }
     // Add score - simplistic approach for now.
     // A real implementation might check if the score is high enough first,
     // or prune the list after insertion to maintain a fixed size (e.g., top 20).
     try {
       const collection = this.getCollection(gameType);
       const result = await collection.insertOne({ name, score });
       console.log(`✅ [TopScoreService] Inserted score ${score} for ${name} in ${gameType} (Inserted ID: ${result.insertedId})`);
       return result.acknowledged;
     } catch (error) {
       console.error(`❌ [TopScoreService] Error inserting top score for ${gameType}:`, error);
       return false;
     }
  }
}