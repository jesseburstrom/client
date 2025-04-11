// backend/src/services/GameService.ts

import { Game } from '../models/Game';
import { Player, PlayerFactory } from '../models/Player';
import { Server, Socket } from 'socket.io'; // Import Socket type
import { GameLogService, GameMove } from './GameLogService'; // <-- Import log service and types
import { TopScoreService } from './TopScoreService'; // <-- Import TopScoreService
import { getSelectionLabel } from '../utils/yatzyMapping'; // <-- Import mapping utility
import { GameConfig, getBaseGameType } from '../utils/gameConfig';

/**
 * Service for managing Yatzy games and spectators
 */
export class GameService {
  private games: Map<number, Game> = new Map();
  private spectators: Map<number, Set<string>> = new Map(); // Map<gameId, Set<spectatorId>>
  private gameIdCounter: number = 0;
  private io: Server;
  private gameLogService: GameLogService; // <-- Add log service instance
  private topScoreService: TopScoreService; // <-- Add top score service instance

  constructor(io: Server, gameLogService: GameLogService, topScoreService: TopScoreService) { // <-- Inject services
    this.io = io;
    this.gameLogService = gameLogService; // <-- Store log service instance
    this.topScoreService = topScoreService; // <-- Store top score service instance
  }

  // --- Spectator Management ---

  addSpectator(gameId: number, spectatorId: string): boolean {
    const game = this.games.get(gameId);
    if (!game || game.gameFinished) {
      console.log(`[Spectator] Cannot add spectator ${spectatorId} to non-existent or finished game ${gameId}`);
      return false; // Game doesn't exist or is finished
    }

    if (!this.spectators.has(gameId)) {
      this.spectators.set(gameId, new Set());
    }
    const gameSpectators = this.spectators.get(gameId)!; // Safe due to check above

    if (gameSpectators.has(spectatorId)) {
      console.log(`[Spectator] Spectator ${spectatorId} is already watching game ${gameId}`);
      // Optionally resend current state if needed
    } else {
        gameSpectators.add(spectatorId);
        console.log(`[Spectator] Added spectator ${spectatorId} to game ${gameId}. Total spectators: ${gameSpectators.size}`);
    }


    // Send current game state to the new spectator immediately
    const gameData = game.toJSON();
    gameData.action = 'onGameUpdate'; // Use the standard update action
    this.io.to(spectatorId).emit('onServerMsg', gameData);
    console.log(`[Spectator] Sent initial game state of game ${gameId} to new spectator ${spectatorId}`);

    return true;
  }

  removeSpectator(spectatorId: string): void {
    let removed = false;
    for (const [gameId, gameSpectators] of this.spectators.entries()) {
      if (gameSpectators.delete(spectatorId)) {
        removed = true;
        console.log(`[Spectator] Removed spectator ${spectatorId} from game ${gameId}. Remaining: ${gameSpectators.size}`);
        if (gameSpectators.size === 0) {
          this.spectators.delete(gameId);
          console.log(`[Spectator] No spectators left for game ${gameId}, removing entry.`);
        }
      }
    }
    if (removed) {
        console.log(`[Spectator] Finished removing spectator ${spectatorId} from all games.`);
    }
  }

  // --- Game Management ---

  createGame(gameType: string, maxPlayers: number): Game {
    const gameId = this.gameIdCounter++;
    const game = new Game(gameId, gameType, maxPlayers);
    this.games.set(gameId, game);
    
    // Log game start immediately after creation
    console.log(`📝 [GameService] Creating new game ${gameId} of type ${gameType} for ${maxPlayers} players`);
    this.gameLogService.logGameStart(game)
      .then(() => {
        console.log(`✅ [GameService] Successfully logged game ${gameId} creation to database`);
      })
      .catch(error => {
        console.error(`❌ [GameService] Error logging game ${gameId} creation:`, error);
      });
    
    return game;
  }

  findAvailableGame(gameType: string, maxPlayers: number): Game | null {
    for (const [_, game] of this.games) {
      if (
        game.gameType === gameType &&
        game.maxPlayers === maxPlayers &&
        !game.isGameFull() &&
        !game.gameStarted
      ) {
        return game;
      }
    }
    return null;
  }

  getGame(gameId: number): Game | undefined {
    return this.games.get(gameId);
  }

  getAllGames(): Game[] {
    return Array.from(this.games.values());
  }

  removeGame(gameId: number): boolean {
    // Potentially log game removal/completion before deleting
    const game = this.games.get(gameId);
    if (game && game.gameFinished) {
      const finalScores = game.players
        .filter(p => p?.id) // Filter out empty slots (add null check)
        .map(p => ({ username: p!.username, score: p!.getScore() })); // Assume Player has getScore() method (add non-null assertion)
      
      console.log(`📝 [GameService] Logging game ${gameId} end with scores:`, finalScores);
      this.gameLogService.logGameEnd(gameId, finalScores)
        .then(() => {
          console.log(`✅ [GameService] Successfully logged game ${gameId} end to database`);
        })
        .catch(error => {
          console.error(`❌ [GameService] Error logging game ${gameId} end:`, error);
        });
    }
    return this.games.delete(gameId);
  }

  joinGame(gameId: number, player: Player): Game | null {
    const game = this.games.get(gameId);

    if (!game || game.isGameFull() || game.gameStarted) {
      return null;
    }

    if (game.addPlayer(player)) {
      // Log game start *when the game becomes full and starts*
      if (game.isGameFull()) {
        // Check if it wasn't already started (e.g., player rejoining)
        if (!game.gameStarted) {
          game.gameStarted = true;
          // Update the existing log entry with player IDs if needed, or log an "all players joined" event
          console.log(`📝 [GameService] Game ${gameId} is now full, updating database entry`);
          this.gameLogService.logGameStart(game)
            .then(() => {
              console.log(`✅ [GameService] Successfully updated game ${gameId} with all players in database`);
            })
            .catch(error => {
              console.error(`❌ [GameService] Error updating game ${gameId} in database:`, error);
            });
        }
      }

      return game;
    }

    return null;
  }

  // Modified handlePlayerDisconnect to log the event
  handlePlayerDisconnect(playerId: string): void {
     const affectedGames: number[] = []; // Store IDs of affected games
    let foundPlayer = false; // Track if the player was found in any game

    console.log(`🔌 Handling disconnect/cleanup for player ${playerId}`);

    // Iterate through a COPY of the games map keys to avoid issues if a game is deleted during iteration
    const gameIds = Array.from(this.games.keys());

    for (const gameId of gameIds) {
        const game = this.games.get(gameId); // Get game using the key
        if (!game) continue; // Skip if game was somehow already removed

        const playerIndex = game.findPlayerIndex(playerId);

        // Check if player was found AND ACTIVE in this game
        if (playerIndex !== -1 && game.players[playerIndex]?.isActive) {
            foundPlayer = true; // Mark that we found the player in at least one game
            console.log(`🎮 Player ${playerId} found active in game ${gameId}. Initiating cleanup.`);
            affectedGames.push(gameId);

            // Log the disconnect move *before* changing state
            const disconnectMove: GameMove = {
                turnNumber: game.getCurrentTurnNumber(),
                playerIndex: playerIndex,
                playerId: playerId, // Log the ID that disconnected
                action: 'disconnect', // Use a specific action type
                timestamp: new Date(),
            };
            // Log asynchronously, don't wait
            this.gameLogService.logMove(gameId, disconnectMove)
                .then(() => console.log(`✅ Logged disconnect for player ${playerId} in game ${gameId}`))
                .catch(error => console.error(`❌ Error logging disconnect for player ${playerId} in game ${gameId}:`, error));

            // Mark the player as aborted IN THE GAME STATE
            // The Game model's method handles turn advancement, checking finish state internally
            const wasCurrentPlayer = game.playerToMove === playerIndex;
            game.markPlayerAborted(playerId); // This might set game.gameFinished

            console.log(`🎮 Player ${playerId} marked as aborted in game ${gameId}. Active players: ${game.players.filter(p => p?.isActive).length}`);

            // Check if the game finished AS A RESULT of this player leaving
            if (game.gameFinished) {
                console.log(`🏁 Game ${gameId} finished due to player disconnect/abort.`);
                // IMPORTANT: handleGameFinished removes the game from the map
                this.handleGameFinished(game); // This handles logging end and cleanup
            } else {
                // If the game is NOT finished, notify remaining players about the state change
                console.log(`📢 Notifying remaining players in game ${gameId} about player ${playerId} disconnect.`);
                this.notifyGameUpdate(game); // Send update with the player marked inactive
            }
        } else if (playerIndex !== -1) {
             console.log(`🎮 Player ${playerId} found in game ${gameId}, but was already inactive.`);
        }
    } // End of loop through games

    if (!foundPlayer) {
             console.log(`🔌 Player ${playerId} not found in any active games. No server-side game cleanup needed.`);
    }

    // If any games were affected (player removed or game ended), broadcast the updated list
    // This happens AFTER the loop, ensuring cleanup is done first.
    // Note: handleGameFinished also calls broadcastGameList, so this might be redundant
    // if the only affected games were finished. Let's keep it for cases where a player
    // leaves but the game continues.
    if (affectedGames.length > 0 && affectedGames.some(id => this.games.has(id))) { // Check if any *ongoing* games were affected
         console.log(`📢 Broadcasting updated game list after player ${playerId} cleanup.`);
         this.broadcastGameList();
    }

    // Also remove the disconnected user if they were a spectator
    this.removeSpectator(playerId);
  }

  broadcastGameList(): void {
    const gameList = Array.from(this.games.values())
      // Keep started games if they still have active players (or if spectator is allowed)
      // Filter out finished games explicitly if they are removed by handleGameFinished
      .filter(game => !game.gameFinished) // Filter out finished games
      .map(game => game.toJSON()); // Convert to JSON safe representation

    this.io.emit('onServerMsg', {
      action: 'onRequestGames',
      Games: gameList
    });
    console.log(`📢 Broadcasted game list: ${gameList.length} games available`);
  }

  broadcastGameListToPlayer(playerId: string): void {
    const gameList = Array.from(this.games.values())
      .filter(game => !game.gameFinished)
      .map(game => game.toJSON());

    this.io.to(playerId).emit('onServerMsg', {
      action: 'onRequestGames',
      Games: gameList
    });

    console.log(`🎮 Sent game list to player ${playerId} - ${gameList.length} games available`);
  }

  notifyGameUpdate(game: Game): void {
    // --- Recalculate ALL players' derived scores before sending update ---
    // Ensures Sum/Bonus/Total are always up-to-date in the sent payload.
    // Potential scores are handled by calculatePotentialScores/clearPotentialScores calls elsewhere.
    game.players.forEach(p => {
        if (p) { // Calculate even for inactive players so spectators see correct final sums
             p.calculateDerivedScores(); // Recalculates Sum/Bonus/Total based on fixed cells
        }
    });
    // --- End Recalculation ---

    const gameData = game.toJSON(); // Serialize the final state
    gameData.action = 'onGameUpdate';

    // console.log(`🎮 Notifying players about game ${game.id} update`); // Less verbose log

    // Send to all players (active or not) and spectators
    for (const player of game.players) {
        if (player?.id) {
            this.io.to(player.id).emit('onServerMsg', gameData);
        }
    }
    const gameSpectators = this.spectators.get(game.id);
    if (gameSpectators) {
       for (const spectatorId of gameSpectators) {
           this.io.to(spectatorId).emit('onServerMsg', gameData);
       }
    }
  }
  // notifyGameUpdate(game: Game): void {
  //   // --- Recalculate ALL players' derived scores before sending update ---
  //       // Ensures Sum/Bonus/Total are always up-to-date in the sent payload.
  //       // Potential scores are handled by calculatePotentialScores/clearPotentialScores calls elsewhere.
  //       game.players.forEach(p => {
  //         if (p) { // Calculate even for inactive players so spectators see correct final sums
  //              p.calculateDerivedScores(); // Recalculates Sum/Bonus/Total based on fixed cells
  //         }
  //     });
  //     // --- End Recalculation ---
  //   const gameData = game.toJSON();

  //   // Determine action based on game state
  //   // gameData.action = game.gameStarted ? 'onGameStart' : 'onGameUpdate'; // Logic seems reversed, usually update after start? Let's use onGameUpdate generally after start.
  //   // Let's stick to onGameUpdate for general updates after the initial start signal
  //   gameData.action = 'onGameUpdate';

  //   console.log(`🎮 Notifying players about game ${game.id} update, action: ${gameData.action}`);

  //   for (let i = 0; i < game.players.length; i++) {
  //     const player = game.players[i];
  //     // Send update to active players
  //     if (player?.isActive && player.id) { // Add null check
  //       console.log(`🎮 Sending ${gameData.action} to player ${i} (${player.id})`);
  //       this.io.to(player.id).emit('onServerMsg', gameData);
  //     }
  //   }

  //   // Notify spectators
  //   const gameSpectators = this.spectators.get(game.id);
  //   if (gameSpectators && gameSpectators.size > 0) {
  //     console.log(`[Spectator] Notifying ${gameSpectators.size} spectators of game ${game.id} update`);
  //     for (const spectatorId of gameSpectators) {
  //       this.io.to(spectatorId).emit('onServerMsg', gameData);
  //     }
  //   }
  // }

  handlePlayerStartingNewGame(playerId: string): void {
    // This function essentially forces a disconnect/abort from existing games
    console.log(`🎮 Player ${playerId} starting new game, handling potential disconnects from old games.`);
    this.handlePlayerDisconnect(playerId); // Re-use the disconnect logic
  }

  handlePlayerAbort(playerId: string): void {
    // This might be redundant if handlePlayerDisconnect covers it.
    console.log(`🎮 Player ${playerId} explicitly aborting.`);
    this.handlePlayerDisconnect(playerId); // Re-use disconnect logic which includes logging.
  }


  handleGameFinished(game: Game): void {
    console.log(`🏁 Game ${game.id} finished.`);
    // Log game end with final scores
    const finalScores = game.players
      .filter(p => p?.id) // Make sure player slot wasn't empty (add null check)
      .map(p => ({ username: p!.username, score: p!.getScore() })); // Assume Player has getScore method (add non-null assertion)
    
    console.log(`📝 [GameService] Logging game ${game.id} finish with scores:`, finalScores);
    this.gameLogService.logGameEnd(game.id, finalScores)
      .then(() => {
        console.log(`✅ [GameService] Successfully logged game ${game.id} end to database`);
      })
      .catch(error => {
        console.error(`❌ [GameService] Error logging game ${game.id} end:`, error);
      });

    // **** Update Top Scores ****
    console.log(`🏆 [GameService] Attempting to update top scores for game ${game.id} (Type: ${game.gameType})`);
    const scoreUpdatePromises = finalScores.map(playerScore => {
      if (playerScore.username && playerScore.score > 0) { // Basic check
         // Important: updateTopScore now broadcasts internally
         return this.topScoreService.updateTopScore(game.gameType, playerScore.username, playerScore.score)
           .then(success => {
              if (success) console.log(`🏆 [TopScoreService] Score update initiated for ${playerScore.username}`);
              // No need to log success here, updateTopScore handles its own logging/broadcasting
           })
           .catch(err => console.error(`❌ [TopScoreService] Error initiating score update for ${playerScore.username}:`, err));
      }
      return Promise.resolve(); // Return a resolved promise for players with no score
    });

    // Wait for all score updates to attempt broadcasting before proceeding
    Promise.all(scoreUpdatePromises).then(() => {
        console.log(`🏁 [GameService] Finished attempting top score updates for game ${game.id}.`);
        // Note: Broadcasting now happens within updateTopScore
    });
    // **************************

    // Notify all active players (and spectators) about the game finish
    this.notifyGameFinished(game);

    // Remove the game from the active games map
    this.games.delete(game.id); // Remove the game *after* notifying

    // Clean up spectators for this game
    if (this.spectators.has(game.id)) {
      console.log(`[Spectator] Removing ${this.spectators.get(game.id)?.size} spectators from finished game ${game.id}`);
      this.spectators.delete(game.id);
    }

    // Broadcast updated game list (game is removed)
    this.broadcastGameList();
  }

  notifyGameFinished(game: Game): void {
    const gameData = game.toJSON(); // Get final game state
    gameData.action = 'onGameFinished'; // Use a specific action

    console.log(`🏁 Notifying players about game ${game.id} finish`);
    for (const player of game.players) {
      if (player?.id) { // Notify even inactive players about the end? Or just active? Let's notify all who were ever part of it. (add null check)
        this.io.to(player.id).emit('onServerMsg', gameData);
      }
    }

    // Notify spectators
    const gameSpectators = this.spectators.get(game.id);
    if (gameSpectators && gameSpectators.size > 0) {
      console.log(`[Spectator] Notifying ${gameSpectators.size} spectators of game ${game.id} finish`);
      for (const spectatorId of gameSpectators) {
        this.io.to(spectatorId).emit('onServerMsg', gameData);
      }
    }
  }

  // Modified processDiceRoll to log the move
  async processDiceRoll(gameId: number, playerId: string, diceValues: number[], keptDice: boolean[], isRegret: boolean = false, isExtra: boolean = false): Promise<boolean> {
    const game = this.games.get(gameId);
    if (!game) {
      console.error(`❌ [GameService] processDiceRoll: Game ${gameId} not found`);
      return false;
    }

    const playerIndex = game.findPlayerIndex(playerId);
    if (playerIndex === -1 || playerIndex !== game.playerToMove) {
      console.error(`❌ [GameService] processDiceRoll: Invalid player ${playerId} (index ${playerIndex}) or not their turn (current: ${game.playerToMove})`);
      return false;
    }

    // --- Logging ---
    const rollMove: GameMove = {
      turnNumber: game.getCurrentTurnNumber(),
      playerIndex: playerIndex,
      playerId: playerId,
      action: 'roll',
      diceValues: [...diceValues],
      keptDice: [...keptDice],
      timestamp: new Date(),
    };

    console.log(`📝 [GameService] Logging dice roll for game ${gameId}: [${diceValues.join(', ')}]`);
    try {
      await this.gameLogService.logMove(gameId, rollMove);
      console.log(`✅ [GameService] Successfully logged dice roll for game ${gameId}`);
    } catch (error) {
      console.error(`❌ [GameService] Error logging dice roll for game ${gameId}:`, error);
    }
    // --- End Logging ---

    // --- Update Game State ---
    game.setDiceValues(diceValues);
    game.incrementRollCount();
    console.log(`🎲 [GameService] Game ${game.id} state updated: Roll ${game.rollCount}, Dice ${game.diceValues}`);
    // --- End Update Game State ---

     // Clear potential scores for ALL players FIRST
        //    This ensures the previous player's potential scores are gone before calculating new ones.
        console.log(`[GameService] Clearing potentials for ALL players before calculating new ones.`);
        game.players.forEach(p => {
            if (p) {
                p.clearPotentialScores(); // Resets non-fixed values to -1 and updates derived scores
            }
        });

      // --- *** ADDED: Calculate Potential Scores for Current Player *** ---
      const currentPlayer = game.players[playerIndex];
      if (currentPlayer) {
          currentPlayer.calculatePotentialScores(diceValues); // This updates the .value of unfixed cells
          // Also recalculate derived scores like Sum/Bonus/Total for display consistency
          currentPlayer.calculateScores();
      }
      // --- *** END ADDED *** ---

    // --- Notify other players via onClientMsg (for potential direct dice display updates) ---
    // const diceUpdateData = {
    //   action: 'sendDices',
    //   gameId: game.id,
    //   diceValue: diceValues,
    //   rollCount: game.rollCount
    // };

    // console.log(`🎲 Broadcasting 'sendDices' (onClientMsg) for game ${game.id}`);
    // for (let i = 0; i < game.players.length; i++) {
    //   const player = game.players[i];
    //   if (player?.isActive && player.id && player.id !== playerId) {
    //     this.io.to(player.id).emit('onClientMsg', diceUpdateData);
    //   }
    // }
    // --- End Notify other players ---


    // --- Notify ALL players AND spectators via onServerMsg (for full state sync) ---
    // This is the crucial addition for spectators to get updated dice/roll count
    console.log(`🔄 Notifying full game update (onServerMsg) after dice roll for game ${game.id}`);
    this.notifyGameUpdate(game);
    // --- End Notify ALL ---

    // // Also send dice update to spectators via onClientMsg if needed for specific client logic
    // const gameSpectators = this.spectators.get(game.id);
    // if (gameSpectators && gameSpectators.size > 0) {
    //   console.log(`[Spectator] Sending 'sendDices' (onClientMsg) to ${gameSpectators.size} spectators`);
    //   for (const spectatorId of gameSpectators) {
    //      this.io.to(spectatorId).emit('onClientMsg', diceUpdateData);
    //   }
    // }


    return true;
  }

  // Modified processSelection to log the move with label and score
  async processSelection(gameId: number, playerId: string, selectionLabel: string, score: number): Promise<boolean> {
    const game = this.games.get(gameId);
    if (!game) {
      console.error(`❌ [GameService] processSelection: Game ${gameId} not found`);
      return false;
    }

    const playerIndex = game.findPlayerIndex(playerId);
    if (playerIndex === -1 || playerIndex !== game.playerToMove) {
      console.error(`❌ [GameService] processSelection: Invalid player ${playerId} (index ${playerIndex}) or not their turn (current: ${game.playerToMove})`);
      return false;
    }

    const currentPlayer = game.players[playerIndex];
    if (!currentPlayer) return false; // Should not happen

    console.log(`📝 [GameService] Processing selection for game ${gameId}: Player ${playerIndex} selected ${selectionLabel} for ${score} points`);

    // --- Logging ---
    const selectMove: GameMove = {
      turnNumber: game.getCurrentTurnNumber(),
      playerIndex: playerIndex,
      playerId: playerId,
      action: 'select',
      selectionLabel: selectionLabel,
      score: score, // Include the score achieved
      diceValues: [...game.diceValues], // Log the dice that led to the selection
      timestamp: new Date(),
    };
    
    console.log(`📝 [GameService] Logging selection move to database for game ${gameId}`);
    try {
      await this.gameLogService.logMove(gameId, selectMove);
      console.log(`✅ [GameService] Successfully logged selection move to database for game ${gameId}`);
      
      // Verify the move was stored
      const gameLog = await this.gameLogService.getGameLog(gameId);
      if (gameLog) {
        const selections = gameLog.moves.filter(move => move.action === 'select');
        console.log(`📊 [GameService] Game ${gameId} now has ${selections.length} selection moves in database`);
      } else {
        console.error(`❌ [GameService] Game log not found in database after logging move for game ${gameId}`);
      }
    } catch (error) {
      console.error(`❌ [GameService] Error logging selection move to database for game ${gameId}:`, error);
    }
    // --- End Logging ---

    // Apply selection in Game model
    console.log(`📝 [GameService] Applying selection to game state: ${selectionLabel} with score ${score}`);
    game.applySelection(playerIndex, selectionLabel, score);

    // --- Recalculate derived scores (Sum, Bonus, Total) for the player who just selected ---
    //currentPlayer.calculateScores();
    game.players.forEach(p => {
      if (p) {
          p.clearPotentialScores(); // Resets non-fixed values to -1 and updates derived scores
      }
    });
    //currentPlayer.calculateDerivedScores();

    // Debug: Log cell values after selection
    const player = game.players[playerIndex];
    if (player && player.cells) {
      console.log(`📊 [GameService] Cell values after selection for player ${playerIndex}:`);
      for (const cell of player.cells) {
        if (cell && cell.fixed) {
          console.log(`   - ${cell.label}: ${cell.value}`);
        }
      }
    }

    // Check if game finished after this selection
    if (game.isGameFinished()) {
      console.log(`🏁 [GameService] Game ${gameId} finished after selection`);
      // --- *** ADDED: Clear potential scores before final update *** ---
      // Not strictly necessary as game is over, but good practice
      currentPlayer.clearPotentialScores(); // Clear for the player who made the last move
      // --- *** END ADDED *** ---
      // **** CRUCIAL FIX: Send final update BEFORE handling finish ****
      console.log(`🔄 Notifying final game update (onServerMsg) before finishing game ${game.id}`);
      this.notifyGameUpdate(game); // Send state including the last selection
      // ***************************************************************

      this.handleGameFinished(game); // This handles logging end, notifying, removing game
    } else {
      // Advance turn to the next active player FIRST
      game.advanceToNextActivePlayer();
      const nextPlayerIndex = game.playerToMove;
      const nextPlayer = game.players[nextPlayerIndex];

       // --- Clear potential scores for the player whose turn it is NOW ---
       if (nextPlayer) {
           console.log(`[GameService] Clearing potential scores for next player ${nextPlayerIndex} (${nextPlayer.username})`);
           nextPlayer.clearPotentialScores(); // Resets non-fixed values to -1 and recalculates derived scores
       } else {
           console.warn(`[GameService] Could not find next player at index ${nextPlayerIndex} to clear scores.`);
       }
       // --- End Clearing Potential Scores ---

      // --- Reset dice state for the *game* dynamically ---
      const config = GameConfig[getBaseGameType(game.gameType)];
      const diceCount = config.diceCount;
      const zeroDiceArray = new Array(diceCount).fill(0); // Create array of 0s with correct length
      game.setDiceValues(zeroDiceArray); // Use the dynamic array
      game.rollCount = 0;
      // --- End Resetting Dice State ---

      console.log(`🎮 [GameService] Advanced turn to player ${game.playerToMove}. Dice reset.`);

      // --- Notify ALL clients (players and spectators) of the updated game state ONCE ---
      // notifyGameUpdate handles serialization and sending to players/spectators.
      // It will send the state *after* potential scores are cleared and dice are reset.
      this.notifyGameUpdate(game);
      // --- End Notification ---
    }

    return true;
  }

  // Modified forwardSelectionToPlayers to use label
  forwardSelectionToPlayers(gameId: number, senderId: string, selectionData: any): boolean {
    const game = this.games.get(gameId);
    if (!game) {
      console.log(`🎮 Cannot forward selection: Game ${gameId} not found`);
      return false;
    }

    // Ensure selectionData has the label
    if (!selectionData.selectionLabel) {
      console.error("❌ Selection data missing 'selectionLabel'");
      // Try to map from index if available (fallback for older clients?)
      if (typeof selectionData.cell === 'number') {
        selectionData.selectionLabel = getSelectionLabel(game.gameType, selectionData.cell);
        if (!selectionData.selectionLabel) return false; // Mapping failed
      } else {
        return false; // Cannot proceed without label or index
      }
    }

    console.log(`🎮 Forwarding selection for game ${gameId} from player ${senderId}: ${selectionData.selectionLabel}`);

    const messageToSend = {
      action: 'sendSelection', // Keep original action name client expects
      gameId: gameId,
      player: game.findPlayerIndex(senderId), // Send player index
      selectionLabel: selectionData.selectionLabel, // Send label
      diceValue: selectionData.diceValue, // Include dice for context
      // Include score if available in original data?
      score: selectionData.score // Assuming score might be sent by client
    };


    for (const player of game.players) {
      if (player?.isActive && player.id && player.id !== senderId) { // Add null check
        console.log(`🎮 Sending selection to player ${player.id}`);
        this.io.to(player.id).emit('onClientMsg', messageToSend);
      }
    }

    return true;
  }

  // Modified createOrJoinGame to handle logging
  createOrJoinGame(gameType: string, maxPlayers: number, player: Player): Game {
    // --- ADDED Validation ---
    const allowedTypes = ['Ordinary', 'Maxi'];
    if (!allowedTypes.includes(gameType)) {
        console.error(`[GameService] Attempt to create/join invalid game type: ${gameType}`);
        // How to handle? Throw error? Return null? For now, log and default.
        // Ideally, the controller should prevent this. Let's default to Ordinary.
        gameType = 'Ordinary';
        console.warn(`[GameService] Defaulting to 'Ordinary' game type.`);
    }
    // --- End Validation ---
    this.handlePlayerStartingNewGame(player.id); // Handle leaving old games

    let game = this.findAvailableGame(gameType, maxPlayers);
    let isNewGame = false;

    if (!game) {
      console.log(`🎮 Creating new ${gameType} game for ${maxPlayers} players`);
      game = this.createGame(gameType, maxPlayers); // createGame now logs start implicitly
      isNewGame = true;
    } else {
      console.log(`🎮 Found existing game ${game.id} for player ${player.id} to join`);
    }

    game.addPlayer(player);

    // Update log if it's an existing game being joined
    if (!isNewGame) {
      console.log(`📝 [GameService] Updating existing game ${game.id} in database with new player ${player.id}`);
      this.gameLogService.logGameStart(game) // This updates the log with current players
        .then(() => {
          console.log(`✅ [GameService] Successfully updated game ${game.id} with new player in database`);
        })
        .catch(error => {
          console.error(`❌ [GameService] Error updating game ${game.id} in database:`, error);
        });
    }

    const activeCount = game.players.filter(p => p?.isActive).length; // Add null check

    if (game.isGameFull()) {
      if (activeCount === maxPlayers) {
        if (!game.gameStarted) { // Only set and log if it wasn't already started
          game.gameStarted = true;
          console.log(`🎮 Game ${game.id} started with ${activeCount} active players`);
          // Log an event indicating the game actually started? Optional.
          // this.gameLogService.logMove(game.id, { turnNumber: 0, playerIndex: -1, playerId: '', action: 'game_start_full', timestamp: new Date() });

          // Re-log start to ensure player list is up-to-date in the log and mark started
          console.log(`📝 [GameService] Marking game ${game.id} as started in database`);
          this.gameLogService.logGameStart(game) // Updates game log with started status and players
            .then(() => {
              console.log(`✅ [GameService] Successfully marked game ${game.id} as started in database`);
            })
            .catch(error => {
              console.error(`❌ [GameService] Error marking game ${game.id} as started in database:`, error);
            });
        }
      } else {
        console.log(`🎮 Game ${game.id} has ${activeCount}/${maxPlayers} active players, waiting`);
      }
    } else {
      console.log(`🎮 Game ${game.id} has ${game.connectedPlayers}/${maxPlayers} connected, waiting`);
    }

    // Notify players (onServerMsg includes game state)
    // Send 'onGameStart' specifically if the game just started, otherwise 'onGameUpdate'
    if (game.gameStarted && activeCount === maxPlayers) {
      const gameData = game.toJSON();
      gameData.action = 'onGameStart'; // Override action for initial start
      console.log(`🎮 Sending explicit onGameStart for game ${game.id}`);
      for (const p of game.players) {
        if (p?.isActive && p.id) { // Add null check
          this.io.to(p.id).emit('onServerMsg', gameData);
        }
      }
    } else {
      // Send general update if game not starting right now
      this.notifyGameUpdate(game);
    }

    this.broadcastGameList(); // Broadcast updated list

    return game; // <-- Ensure game is returned
  }


}

// Add helper methods to Game model if they don't exist
// These declarations inform TypeScript about methods implemented in Game.ts
declare module '../models/Game' {
  interface Game {
    getCurrentTurnNumber(): number;
    incrementRollCount(): void;
    applySelection(playerIndex: number, selectionLabel: string, score: number): void;
    isGameFinished(): boolean;
    advanceToNextActivePlayer(): void; // Added this declaration as it's used
  }
}

// Add getScore to Player model if it doesn't exist
// This declaration informs TypeScript about the method implemented in Player.ts
declare module '../models/Player' {
  interface Player {
    getScore(): number;
  }
}