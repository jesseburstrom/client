// backend/src/services/TopScoreService.ts
import { Collection, Db } from 'mongodb';
import { getDbConnection } from '../db';
import { Server } from 'socket.io';

const DB_NAME = 'top-scores';

// Define the supported game types explicitly
const SUPPORTED_GAME_TYPES = ["Mini", "Ordinary", "Maxi"];

interface TopScoreEntry {
  name: string;
  score: number;
}

export class TopScoreService {
  private io: Server;

  constructor(io: Server) {
    this.io = io;
  }

  private getDb(): Db {
    return getDbConnection(DB_NAME);
  }

  private getCollection(gameType: string): Collection<TopScoreEntry> {

    // --- Simplification: Check if type is supported ---
    if (!SUPPORTED_GAME_TYPES.includes(gameType)) {
         console.warn(`[TopScoreService] Unsupported game type requested for collection: ${gameType}`);
         return null;
    }
    // --- End Simplification ---
    const db = this.getDb();
    // Normalize collection name (e.g., MaxiR3 -> maxiR3)
    const collectionName = gameType.charAt(0).toLowerCase() + gameType.slice(1);
    return db.collection<TopScoreEntry>(collectionName);
  }

  /**
   * Gets the top scores for a given game type.
   * @param gameType - The type of game (e.g., "Ordinary", "MaxiR3").
   * @param limit - Optional maximum number of scores to return.
   * @returns An array of top score entries.
   */
  async getTopScores(gameType: string, limit?: number): Promise<TopScoreEntry[]> {
    try {
      // Ensure the game type is supported before querying
      if (!SUPPORTED_GAME_TYPES.includes(gameType)) {
         console.warn(`[TopScoreService] Attempted to get scores for unsupported game type: ${gameType}`);
         return [];
      }
      const collection = this.getCollection(gameType);
      // --- Simplification: Handle null collection ---
     if (!collection) {
          return []; // Return empty if type is not supported
     }
     // --- End Simplification ---
      // Build query dynamically based on limit
      let query = collection
        .find({}, { projection: { _id: 0 } })
        .sort({ score: -1 });

      // Apply limit ONLY if provided
      if (limit !== undefined && limit > 0) {
         query = query.limit(limit);
      }

      const results = await query.toArray();

      console.log(`📊 [TopScoreService] Fetched ${results.length} top scores for ${gameType}${limit ? ' (limited to ' + limit + ')' : ' (all)'}`);
      return results;
    } catch (error) {
      console.error(`❌ [TopScoreService] Error fetching top scores for ${gameType}:`, error);
      return []; // Return empty array on error
    }
  }

  /**
   * Gets top scores for all supported game types.
   * @returns A map where keys are game types and values are arrays of top score entries.
   */
  async getAllTopScores(): Promise<{ [gameType: string]: TopScoreEntry[] }> {
    const allScores: { [gameType: string]: TopScoreEntry[] } = {};
    console.log(`📊 [TopScoreService] Fetching top scores for all supported types: ${SUPPORTED_GAME_TYPES.join(', ')}`);
    for (const gameType of SUPPORTED_GAME_TYPES) {
      // Use the existing getTopScores method
      allScores[gameType] = await this.getTopScores(gameType);
    }
    console.log(`📊 [TopScoreService] Finished fetching all top scores.`);
    return allScores;
  }

  /**
   * Broadcasts all top scores to all connected clients.
   */
  async broadcastTopScores(): Promise<void> {
    try {
      const allScores = await this.getAllTopScores();
      this.io.emit('onTopScoresUpdate', allScores); // Use a specific event name
      console.log(`📢 [TopScoreService] Broadcasted updated top scores to all clients.`);
    } catch (error) {
      console.error(`❌ [TopScoreService] Error broadcasting top scores:`, error);
    }
  }

  /**
   * Attempts to add a new score to the top scores list if it qualifies.
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
     // Ensure the game type is supported before inserting
     if (!SUPPORTED_GAME_TYPES.includes(gameType)) {
        console.warn(`❌ [TopScoreService] Attempted to update score for unsupported game type: ${gameType}`);
        return false;
     }

     try {
       const collection = this.getCollection(gameType);
      // --- Simplification: Handle null collection ---
      if (!collection) {
           console.warn(`❌ [TopScoreService] Cannot update score for unsupported game type: ${gameType}`);
           return false;
      }
      // --- End Simplification ---
       const result = await collection.insertOne({ name, score });
       console.log(`✅ [TopScoreService] Inserted score ${score} for ${name} in ${gameType} (Inserted ID: ${result.insertedId})`);
       return result.acknowledged; // Return insertion status directly
     } catch (error) {
       console.error(`❌ [TopScoreService] Error inserting top score for ${gameType}:`, error);
       return false;
     }
  }
}
