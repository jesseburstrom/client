// backend/src/services/GameService.ts

import { Game } from '../models/Game';
import { Player, PlayerFactory } from '../models/Player';
import { Server, Socket } from 'socket.io'; // Import Socket type
import { GameLogService, GameMove } from './GameLogService'; // <-- Import log service and types
import { getSelectionLabel } from '../utils/yatzyMapping'; // <-- Import mapping utility

/**
 * Service for managing Yatzy games and spectators
 */
export class GameService {
  private games: Map<number, Game> = new Map();
  private spectators: Map<number, Set<string>> = new Map(); // Map<gameId, Set<spectatorId>>
  private gameIdCounter: number = 0;
  private io: Server;
  private gameLogService: GameLogService; // <-- Add log service instance

  constructor(io: Server, gameLogService: GameLogService) { // <-- Inject log service
    this.io = io;
    this.gameLogService = gameLogService; // <-- Store log service instance
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

    for (const [gameId, game] of this.games) {
      const playerIndex = game.findPlayerIndex(playerId);

      // Check if player was found and active in this game
      if (playerIndex !== -1 && game.players[playerIndex]?.isActive) { // Add null check
        console.log(`🎮 Player ${playerId} disconnected from game ${gameId}`);
        affectedGames.push(gameId);

        // Log the disconnect move
        const disconnectMove: GameMove = {
          turnNumber: game.getCurrentTurnNumber(), // Need a method in Game to track turns
          playerIndex: playerIndex,
          playerId: playerId,
          action: 'disconnect',
          timestamp: new Date(),
        };
        
        console.log(`📝 [GameService] Logging disconnect for player ${playerId} in game ${gameId}`);
        this.gameLogService.logMove(gameId, disconnectMove)
          .then(() => {
            console.log(`✅ [GameService] Successfully logged disconnect for player ${playerId} in game ${gameId}`);
          })
          .catch(error => {
            console.error(`❌ [GameService] Error logging disconnect for player ${playerId} in game ${gameId}:`, error);
          });

        // Mark the player as aborted in the game state (Game model handles internal logic)
        game.markPlayerAborted(playerId); // This method handles turn advancement if needed

        // Check if game should end (Game model's markPlayerAborted might set gameFinished)
        if (game.gameFinished) {
          console.log(`🎮 Game ${gameId} finished due to player disconnect/abort`);
          this.handleGameFinished(game); // Handle logging end and cleanup
        } else {
          // Notify remaining players about the disconnection/abort
          this.notifyGameUpdate(game);
        }
      }
    }

    // If any games were affected (player removed or game ended), broadcast the updated list
    if (affectedGames.length > 0) {
      // If games were removed inside handleGameFinished, they won't be in this.games anymore
      // Broadcast updated game list to all clients
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
    const gameData = game.toJSON();

    // Determine action based on game state
    // gameData.action = game.gameStarted ? 'onGameStart' : 'onGameUpdate'; // Logic seems reversed, usually update after start? Let's use onGameUpdate generally after start.
    // Let's stick to onGameUpdate for general updates after the initial start signal
    gameData.action = 'onGameUpdate';

    console.log(`🎮 Notifying players about game ${game.id} update, action: ${gameData.action}`);

    for (let i = 0; i < game.players.length; i++) {
      const player = game.players[i];
      // Send update to active players
      if (player?.isActive && player.id) { // Add null check
        console.log(`🎮 Sending ${gameData.action} to player ${i} (${player.id})`);
        this.io.to(player.id).emit('onServerMsg', gameData);
      }
    }

    // Notify spectators
    const gameSpectators = this.spectators.get(game.id);
    if (gameSpectators && gameSpectators.size > 0) {
      console.log(`[Spectator] Notifying ${gameSpectators.size} spectators of game ${game.id} update`);
      for (const spectatorId of gameSpectators) {
        this.io.to(spectatorId).emit('onServerMsg', gameData);
      }
    }
  }

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

    // Notify all active players
    this.notifyGameFinished(game);

    // Remove the game from the active games map
    this.games.delete(game.id); // Remove the game *after* notifying

    // Clean up spectators for this game
    if (this.spectators.has(game.id)) {
      console.log(`[Spectator] Removing ${this.spectators.get(game.id)?.size} spectators from finished game ${game.id}`);
      this.spectators.delete(game.id);
    }

    // Broadcast updated game list
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
    // Log regret/extra move actions separately when they are *used* (handled by controller/logRegret/logExtraMove)
    // Log the roll itself here.
    const rollMove: GameMove = {
      turnNumber: game.getCurrentTurnNumber(),
      playerIndex: playerIndex,
      playerId: playerId,
      action: 'roll', // Log as a standard roll
      diceValues: [...diceValues],
      keptDice: [...keptDice], // Log which dice were kept *before* this roll
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

    game.setDiceValues(diceValues);
    game.incrementRollCount(); // Ensure Game model tracks roll count

    // Notify all players of the dice roll
    const gameData = {
      action: 'sendDices', // Use the action name client expects for peer updates
      gameId: game.id,
      // playerIds: game.players.map(p => p?.id ?? ""), // Send current IDs (handle null) - Not needed if using onClientMsg?
      diceValue: diceValues,
      rollCount: game.rollCount // Include roll count
    };

    // Send dice update via onClientMsg to other players AND spectators
    console.log(`🎲 Broadcasting dice update for game ${game.id}`);
    for (let i = 0; i < game.players.length; i++) {
      const player = game.players[i];
      if (player?.isActive && player.id && player.id !== playerId) { // Add null check, send to others only
        this.io.to(player.id).emit('onClientMsg', gameData);
      }
    }

    // Also send to spectators
    const gameSpectators = this.spectators.get(game.id);
    if (gameSpectators && gameSpectators.size > 0) {
      console.log(`[Spectator] Sending dice update to ${gameSpectators.size} spectators`);
      for (const spectatorId of gameSpectators) {
        this.io.to(spectatorId).emit('onClientMsg', gameData);
      }
    }

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
      this.handleGameFinished(game); // This handles logging end, notifying, removing game
    } else {
      // Clear dice for next player
      game.setDiceValues([0, 0, 0, 0, 0]);
      game.rollCount = 0;
      
      // Advance to next player
      game.advanceToNextActivePlayer();
      console.log(`🎮 [GameService] Player ${playerId} processed selection, advancing to player ${game.playerToMove}`);
      
      // Notify all players and spectators of the game update
      this.notifyGameUpdate(game);
      
      // Prepare full game state with cleared dice
      const gameData = game.toJSON();
      gameData.action = 'onGameUpdate';
      gameData.diceValues = [0, 0, 0, 0, 0];
      gameData.rollCount = 0;

      // Send to all players
      for (const player of game.players) {
        if (player?.id) {
          this.io.to(player.id).emit('onServerMsg', gameData);
        }
      }
      
      // Send to all spectators
      const spectators = this.spectators.get(game.id);
      if (spectators) {
        for (const spectatorId of spectators) {
          this.io.to(spectatorId).emit('onServerMsg', gameData);
        }
      }
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
      // Update the game start log with the new player list?
      console.log(`📝 [GameService] Updating existing game ${game.id} in database with new player ${player.id}`);
      this.gameLogService.logGameStart(game)
        .then(() => {
          console.log(`✅ [GameService] Successfully updated game ${game.id} with new player in database`);
        })
        .catch(error => {
          console.error(`❌ [GameService] Error updating game ${game.id} in database:`, error);
        });
    }

    // Define activeCount here to use in the 'if' and 'else if' blocks below
    const activeCount = game.players.filter(p => p?.isActive).length; // Add null check

    if (game.isGameFull()) {
      // const activeCount = game.players.filter(p => p?.isActive).length; // Moved definition up
      if (activeCount === maxPlayers) {
        if (!game.gameStarted) { // Only set and log if it wasn't already started
          game.gameStarted = true;
          console.log(`🎮 Game ${game.id} started with ${activeCount} active players`);
          // Log an event indicating the game actually started? Optional.
          // this.gameLogService.logMove(game.id, { turnNumber: 0, playerIndex: -1, playerId: '', action: 'game_start_full', timestamp: new Date() });
          // Re-log start to ensure player list is up-to-date in the log
          console.log(`📝 [GameService] Marking game ${game.id} as started in database`);
          this.gameLogService.logGameStart(game)
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

    return game;
  }

  // --- New methods for logging special actions ---
  async logRegret(gameId: number, playerId: string) {
    const game = this.getGame(gameId);
    if (!game) {
      console.error(`❌ [GameService] logRegret: Game ${gameId} not found`);
      return;
    }
    
    const playerIndex = game.findPlayerIndex(playerId);
    if (playerIndex === -1) {
      console.error(`❌ [GameService] logRegret: Player ${playerId} not found in game ${gameId}`);
      return;
    }

    const regretMove: GameMove = {
      turnNumber: game.getCurrentTurnNumber(),
      playerIndex: playerIndex,
      playerId: playerId,
      action: 'regret',
      timestamp: new Date(),
    };
    
    console.log(`📝 [GameService] Logging regret for player ${playerId} in game ${gameId}`);
    try {
      await this.gameLogService.logMove(gameId, regretMove);
      console.log(`✅ [GameService] Successfully logged regret for player ${playerId}`);
    } catch (error) {
      console.error(`❌ [GameService] Error logging regret for player ${playerId}:`, error);
    }
  }

  async logExtraMove(gameId: number, playerId: string) {
    const game = this.getGame(gameId);
    if (!game) {
      console.error(`❌ [GameService] logExtraMove: Game ${gameId} not found`);
      return;
    }
    
    const playerIndex = game.findPlayerIndex(playerId);
    if (playerIndex === -1) {
      console.error(`❌ [GameService] logExtraMove: Player ${playerId} not found in game ${gameId}`);
      return;
    }

    const extraMove: GameMove = {
      turnNumber: game.getCurrentTurnNumber(),
      playerIndex: playerIndex,
      playerId: playerId,
      action: 'extraMove',
      timestamp: new Date(),
    };
    
    console.log(`📝 [GameService] Logging extra move for player ${playerId} in game ${gameId}`);
    try {
      await this.gameLogService.logMove(gameId, extraMove);
      console.log(`✅ [GameService] Successfully logged extra move for player ${playerId}`);
    } catch (error) {
      console.error(`❌ [GameService] Error logging extra move for player ${playerId}:`, error);
    }
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
  }
}

// Add getScore to Player model if it doesn't exist
// This declaration informs TypeScript about the method implemented in Player.ts
declare module '../models/Player' {
  interface Player {
    getScore(): number;
  }
}
