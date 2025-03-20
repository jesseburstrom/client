import { Game } from '../models/Game';
import { Player, PlayerFactory } from '../models/Player';
import { Server } from 'socket.io';

/**
 * Service for managing Yatzy games
 */
export class GameService {
  private games: Map<number, Game> = new Map();
  private gameIdCounter: number = 0;
  private io: Server;

  constructor(io: Server) {
    this.io = io;
  }

  /**
   * Create a new game
   * @param gameType Type of Yatzy game (e.g., "Ordinary", "Mini", "Maxi")
   * @param maxPlayers Maximum number of players
   * @returns Newly created game
   */
  createGame(gameType: string, maxPlayers: number): Game {
    const gameId = this.gameIdCounter++;
    const game = new Game(gameId, gameType, maxPlayers);
    this.games.set(gameId, game);
    return game;
  }

  /**
   * Find an available game of specified type and player count
   * @param gameType Type of game to find
   * @param maxPlayers Number of players
   * @returns Available game or null if none found
   */
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

  /**
   * Get a game by ID
   * @param gameId ID of game to retrieve
   * @returns Game or undefined if not found
   */
  getGame(gameId: number): Game | undefined {
    return this.games.get(gameId);
  }

  /**
   * Get all games
   * @returns Array of all games
   */
  getAllGames(): Game[] {
    return Array.from(this.games.values());
  }

  /**
   * Remove a game by ID
   * @param gameId ID of game to remove
   * @returns true if game was removed, false if game was not found
   */
  removeGame(gameId: number): boolean {
    return this.games.delete(gameId);
  }

  /**
   * Join a player to a specific game
   * @param gameId ID of game to join
   * @param player Player to join
   * @returns Game object if joined successfully, null otherwise
   */
  joinGame(gameId: number, player: Player): Game | null {
    const game = this.games.get(gameId);
    
    if (!game || game.isGameFull() || game.gameStarted) {
      return null;
    }
    
    if (game.addPlayer(player)) {
      // Start game if all players have joined
      if (game.isGameFull()) {
        game.gameStarted = true;
      }
      
      return game;
    }
    
    return null;
  }

  /**
   * Handle player disconnection/abort
   * @param playerId ID of player who disconnected
   */
  handlePlayerDisconnect(playerId: string): void {
    // Find all games this player is part of
    for (const [gameId, game] of this.games) {
      const playerIndex = game.findPlayerIndex(playerId);
      
      if (playerIndex !== -1) {
        console.log(`🎮 Player ${playerId} disconnected from game ${gameId}`);
        
        // Mark the player as aborted
        game.abortedPlayers[playerIndex] = true;
        game.players[playerIndex].isActive = false;
        game.playerIds[playerIndex] = ""; // For backward compatibility
        
        // Check if there are any active players left
        const activePlayersLeft = game.players.filter(p => p.isActive).length;
        console.log(`🎮 Game ${gameId} has ${activePlayersLeft} active players left`);
        
        if (activePlayersLeft === 0) {
          // No active players left, remove the game
          console.log(`🎮 Removing game ${gameId} as all players are inactive`);
          this.games.delete(gameId);
        } else {
          // Check if we need to advance the turn
          if (game.playerToMove === playerIndex) {
            game.advanceToNextActivePlayer();
          }
          
          // Notify remaining players about the disconnection
          this.notifyGameUpdate(game);
        }
      }
    }
    
    // Broadcast updated game list to all clients
    this.broadcastGameList();
  }

  /**
   * Handle player disconnection across all games
   * @param playerId ID of player who disconnected
   */
  handlePlayerDisconnectAcrossAllGames(playerId: string): void {
    const affectedGames: Game[] = [];
    
    // Find all games this player is in
    for (const [gameId, game] of this.games.entries()) {
      if (game.removePlayer(playerId)) {
        affectedGames.push(game);
        
        // If game is empty or all players disconnected, remove it
        if (game.connectedPlayers === 0) {
          this.games.delete(gameId);
        }
      }
    }
    
    // Notify players in affected games
    affectedGames.forEach(game => {
      this.notifyGameUpdate(game);
    });
    
    // Broadcast updated game list to all clients
    this.broadcastGameList();
  }

  /**
   * Broadcast the list of all available games to all clients
   */
  broadcastGameList(): void {
    const gameList = Array.from(this.games.values())
      .filter(game => !game.gameStarted || game.connectedPlayers > 0)
      .map(game => game.toJSON());
      
    this.io.emit('onServerMsg', { 
      action: 'onRequestGames', 
      Games: gameList 
    });
  }

  /**
   * Broadcast the list of all available games to a specific player
   * @param playerId ID of player to send game list to
   */
  broadcastGameListToPlayer(playerId: string): void {
    const gameList = Array.from(this.games.values())
      .filter(game => !game.gameStarted || game.connectedPlayers > 0)
      .map(game => game.toJSON());
    
    // Send only to the specified player
    this.io.to(playerId).emit('onServerMsg', { 
      action: 'onRequestGames', 
      Games: gameList 
    });
    
    console.log(`🎮 Sent game list to player ${playerId} - ${gameList.length} games available`);
  }

  /**
   * Notify all players in a game about updates
   * @param game Game that was updated
   */
  notifyGameUpdate(game: Game): void {
    const gameData = game.toJSON();
    
    // Set action based on game state - critical fix
    // If game has just started, use onGameStart, otherwise use onGameUpdate
    gameData.action = game.gameStarted ? 'onGameStart' : 'onGameUpdate';
    
    console.log(`🎮 Notifying players about game ${game.id} update, action: ${gameData.action}`);
    
    // Send to all active players in the game
    for (let i = 0; i < game.players.length; i++) {
      const player = game.players[i];
      if (player.isActive && player.id) {
        console.log(`🎮 Sending ${gameData.action} to player ${i} (${player.id})`);
        this.io.to(player.id).emit('onServerMsg', gameData);
      }
    }
  }

  /**
   * Handle a player starting a new game
   * This marks them as having aborted any previous games
   * @param playerId ID of player starting a new game
   */
  handlePlayerStartingNewGame(playerId: string): void {
    // Find all games that this player is in
    const playerGames: Game[] = [];
    
    // Iterate through the games map to find games with this player
    this.games.forEach((game) => {
      if (game.players.some(player => player.id === playerId && player.isActive)) {
        playerGames.push(game);
      }
    });
    
    // If no active games were found for this player, nothing to do
    if (playerGames.length === 0) {
      return;
    }
    
    console.log(`🎮 Player ${playerId} is starting a new game, leaving ${playerGames.length} active games`);
    
    // Handle each game this player is active in
    for (const game of playerGames) {
      console.log(`🎮 Player ${playerId} starting new game, aborting game ${game.id}`);
      
      // Find the player's index in this game
      const playerIndex = game.findPlayerIndex(playerId);
      
      if (playerIndex !== -1) {
        // Mark player as aborted in this game
        game.markPlayerAborted(playerId);
        
        // Set their playerIds entry to empty for backward compatibility
        game.playerIds[playerIndex] = "";
        
        // If this player was the current player to move, advance to the next active player
        if (game.playerToMove === playerIndex) {
          game.advanceToNextActivePlayer();
        }
        
        // Notify all remaining active players about this player aborting
        for (let i = 0; i < game.players.length; i++) {
          const player = game.players[i];
          if (player.isActive && player.id && player.id !== playerId) {
            console.log(`🎮 Notifying player ${player.id} about player ${playerId} aborting game ${game.id}`);
            this.io.to(player.id).emit('onServerMsg', {
              action: 'onGameUpdate',
              ...game.toJSON()
            });
          }
        }
        
        // If the game is finished due to player abort, handle game end
        if (game.gameFinished) {
          console.log(`🎮 Game ${game.id} finished due to player abort`);
          this.handleGameFinished(game);
        }
      }
    }
    
    // Broadcast updated game list to all connected clients
    this.broadcastGameList();
  }

  /**
   * Handle a player aborting a game
   * @param playerId ID of player who aborted
   */
  handlePlayerAbort(playerId: string): void {
    // Find all games that this player is in
    const playerGames: Game[] = [];
    
    // Iterate through the games map to find games with this player
    this.games.forEach((game) => {
      if (game.players.some(player => player.id === playerId && player.isActive)) {
        playerGames.push(game);
      }
    });
    
    // Mark player as aborted in all games
    for (const game of playerGames) {
      console.log(`🎮 Player ${playerId} aborting game ${game.id}`);
      game.markPlayerAborted(playerId);
      
      // Notify all players about the game state change
      this.notifyGameUpdate(game);
      
      // If the game is finished due to player abort, handle game end
      if (game.gameFinished) {
        console.log(`🎮 Game ${game.id} finished due to player abort`);
        this.handleGameFinished(game);
      }
    }
    
    // Broadcast updated game list
    this.broadcastGameList();
  }

  /**
   * Handle a game finishing
   * @param game Game that finished
   */
  handleGameFinished(game: Game): void {
    // Notify all players that the game is finished
    this.notifyGameFinished(game);
    
    // Remove the game from the active games list
    this.removeGame(game.id);
    
    // Broadcast updated game list
    this.broadcastGameList();
  }

  /**
   * Notify all players that a game is finished
   * @param game Game that finished
   */
  notifyGameFinished(game: Game): void {
    // Get all active player IDs in the game
    const activePlayers = game.players
      .filter(player => player.isActive)
      .map(player => player.id);
    
    // Notify each active player
    for (const playerId of activePlayers) {
      this.io.to(playerId).emit('onGameFinished', game.toJSON());
    }
  }

  /**
   * Process a dice roll for a game
   * @param gameId ID of game
   * @param playerId ID of player who rolled
   * @param diceValues Values of dice after roll
   * @returns true if roll was processed, false otherwise
   */
  processDiceRoll(gameId: number, playerId: string, diceValues: number[]): boolean {
    const game = this.games.get(gameId);
    
    if (!game) {
      return false;
    }
    
    const playerIndex = game.findPlayerIndex(playerId);
    
    // Only the player whose turn it is can roll
    if (playerIndex === -1 || playerIndex !== game.playerToMove) {
      return false;
    }
    
    game.setDiceValues(diceValues);
    
    // Notify all players of the dice roll
    const gameData = {
      action: 'sendDices',
      gameId: game.id,
      playerIds: game.playerIds,
      diceValue: diceValues
    };
    
    // Send to all players except the one who rolled
    for (let i = 0; i < game.players.length; i++) {
      const player = game.players[i];
      if (player.isActive && player.id && player.id !== playerId) {
        this.io.to(player.id).emit('onClientMsg', gameData);
      }
    }
    
    return true;
  }

  /**
   * Process selection of a score cell
   * @param gameId ID of game
   * @param playerId ID of player who selected
   * @param cellIndex Index of cell selected
   * @returns true if selection was processed, false otherwise
   */
  processSelection(gameId: number, playerId: string, cellIndex: number): boolean {
    const game = this.games.get(gameId);
    
    if (!game) {
      return false;
    }
    
    const playerIndex = game.findPlayerIndex(playerId);
    
    // Only the player whose turn it is can select
    if (playerIndex === -1 || playerIndex !== game.playerToMove) {
      return false;
    }
    
    // Advance to next player
    game.advanceToNextActivePlayer();
    
    console.log(`🎮 Player ${playerId} processed selection, advancing to player ${game.playerToMove}`);
    
    // Notify all players of the game update
    this.notifyGameUpdate(game);
    
    return true;
  }

  /**
   * Forward a selection message to all players in a game except the sender
   * @param gameId ID of game
   * @param senderId ID of the player who sent the selection
   * @param selectionData Complete selection data to forward
   * @returns true if selection was forwarded, false otherwise
   */
  forwardSelectionToPlayers(gameId: number, senderId: string, selectionData: any): boolean {
    const game = this.games.get(gameId);
    
    if (!game) {
      console.log(`🎮 Cannot forward selection: Game ${gameId} not found`);
      return false;
    }
    
    console.log(`🎮 Forwarding selection for game ${gameId} from player ${senderId}: cell ${selectionData.cell}`);
    
    // Send the selection data to all other players in the game
    for (const player of game.players) {
      if (player.isActive && player.id && player.id !== senderId) {
        console.log(`🎮 Sending selection to player ${player.id}`);
        this.io.to(player.id).emit('onClientMsg', selectionData);
      }
    }
    
    return true;
  }

  /**
   * Create or join a game for a player
   * @param gameType Type of game to create/join
   * @param maxPlayers Maximum number of players
   * @param player Player to add to game
   * @returns Game that was created or joined
   */
  createOrJoinGame(gameType: string, maxPlayers: number, player: Player): Game {
    // First, mark this player as having left any existing games
    this.handlePlayerStartingNewGame(player.id);
    
    // Look for an available game of the requested type
    let game = this.findAvailableGame(gameType, maxPlayers);
    
    // If no game found, create a new one
    if (!game) {
      console.log(`🎮 Creating new ${gameType} game for ${maxPlayers} players`);
      game = this.createGame(gameType, maxPlayers);
    } else {
      console.log(`🎮 Found existing game ${game.id} for player to join`);
    }
    
    // Add player to the game
    game.addPlayer(player);
    
    // Only start single-player games immediately
    if (maxPlayers === 1) {
      game.gameStarted = true;
      console.log(`🎮 Single player game ${game.id} started immediately`);
    } 
    // For multiplayer games, only start if full with ACTIVE players
    else if (game.isGameFull()) {
      // Count actual active players (not aborted)
      const activeCount = game.players.filter(p => p.isActive).length;
      
      // Only start the game if we have the full number of active players
      if (activeCount === maxPlayers) {
        game.gameStarted = true;
        console.log(`🎮 Multiplayer game ${game.id} started with ${activeCount} active players`);
      } else {
        console.log(`🎮 Multiplayer game ${game.id} has ${activeCount}/${maxPlayers} active players, waiting for more`);
      }
    } else {
      console.log(`🎮 Multiplayer game ${game.id} has ${game.connectedPlayers}/${maxPlayers} connected players, waiting for more`);
    }
    
    // Notify all players about the game state
    this.notifyGameUpdate(game);
    
    // Broadcast updated game list to all clients
    this.broadcastGameList();
    
    return game;
  }
}
