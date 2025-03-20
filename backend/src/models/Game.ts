import { Player, PlayerFactory } from './Player';
import { v4 as uuidv4 } from 'uuid';

/**
 * Game model for Yatzy
 * Encapsulates all game-related data and logic
 */
export class Game {
  id: number;
  gameType: string;
  players: Player[];
  maxPlayers: number;
  connectedPlayers: number;
  gameStarted: boolean;
  gameFinished: boolean;
  playerToMove: number;
  diceValues: number[];
  userNames: string[];
  gameId: number; // This is redundant with id but kept for backward compatibility
  playerIds: string[]; // This will be migrated to players array
  abortedPlayers: boolean[]; // Track which players have aborted the game
  
  /**
   * Create a new Game instance
   */
  constructor(id: number, gameType: string, maxPlayers: number) {
    this.id = id;
    this.gameId = id; // For backward compatibility
    this.gameType = gameType;
    this.maxPlayers = maxPlayers;
    this.players = new Array(maxPlayers).fill(null).map(() => PlayerFactory.createEmptyPlayer());
    this.playerIds = new Array(maxPlayers).fill(""); // For backward compatibility
    this.userNames = new Array(maxPlayers).fill(""); // For backward compatibility
    this.abortedPlayers = new Array(maxPlayers).fill(false); // No players have aborted initially
    this.connectedPlayers = 0;
    this.gameStarted = false;
    this.gameFinished = false;
    this.playerToMove = 0;
    this.diceValues = [];
  }

  /**
   * Add a player to the game
   * @param player Player to add
   * @param position Optional position to add player at
   * @returns true if player was added successfully, false otherwise
   */
  addPlayer(player: Player, position: number = -1): boolean {
    // If game is full and position is not specified, can't add player
    if (this.connectedPlayers >= this.maxPlayers && position === -1) {
      return false;
    }

    // If position is specified, use it, otherwise add to first empty slot
    const playerPosition = position !== -1 ? position : this.findEmptySlot();
    
    // If no slot found, can't add player
    if (playerPosition === -1) {
      return false;
    }

    // Add player
    this.players[playerPosition] = player;
    this.playerIds[playerPosition] = player.id; // For backward compatibility
    this.userNames[playerPosition] = player.username; // For backward compatibility
    this.connectedPlayers++;
    
    return true;
  }

  /**
   * Remove a player from the game
   * @param playerId ID of player to remove
   * @returns true if player was removed, false if player was not in game
   */
  removePlayer(playerId: string): boolean {
    const playerIndex = this.findPlayerIndex(playerId);
    
    if (playerIndex === -1) {
      return false;
    }

    // Mark player as inactive but keep their data
    this.players[playerIndex].isActive = false;
    this.playerIds[playerIndex] = ""; // For backward compatibility
    this.abortedPlayers[playerIndex] = true; // Mark player as having aborted
    this.connectedPlayers--;

    // If the game has started but not all players are active, we need to handle this
    if (this.gameStarted && !this.gameFinished) {
      // Check if we need to advance player turn
      if (this.playerToMove === playerIndex) {
        this.advanceToNextActivePlayer();
      }
      
      // Check if we should end the game (only one player left)
      const activePlayers = this.players.filter(p => p.isActive).length;
      if (activePlayers <= 1) {
        console.log(`🎮 Game ${this.id} has only ${activePlayers} active players, marking as finished`);
        this.gameFinished = true;
      }
    } else if (!this.gameStarted) {
      // If the game hasn't started yet, we need to update the game state
      console.log(`🎮 Player aborted before game ${this.id} started, now has ${this.connectedPlayers}/${this.maxPlayers} players`);
    }

    return true;
  }

  /**
   * Mark a player as having aborted without removing them
   * @param playerId ID of player who aborted
   * @returns true if player was marked as aborted, false if player was not in game
   */
  markPlayerAborted(playerId: string): boolean {
    const playerIndex = this.findPlayerIndex(playerId);
    
    if (playerIndex === -1) {
      return false;
    }

    // Mark player as aborted
    this.abortedPlayers[playerIndex] = true;
    this.players[playerIndex].isActive = false;
    
    // Don't clear the playerIds for backward compatibility views
    // but decrement the connected players
    this.connectedPlayers--;

    // If the game has started but not all players are active, we need to handle this
    if (this.gameStarted && !this.gameFinished) {
      // Check if we need to advance player turn
      if (this.playerToMove === playerIndex) {
        this.advanceToNextActivePlayer();
      }
      
      // Check if we should end the game (only one player left)
      const activePlayers = this.players.filter(p => p.isActive).length;
      if (activePlayers <= 1) {
        console.log(`🎮 Game ${this.id} has only ${activePlayers} active players, marking as finished`);
        this.gameFinished = true;
      }
    } else if (!this.gameStarted) {
      // If the game hasn't started yet, we need to update the game state
      console.log(`🎮 Player aborted before game ${this.id} started, now has ${this.connectedPlayers}/${this.maxPlayers} players`);
    }

    return true;
  }

  /**
   * Check if a player has aborted
   * @param playerIndex Index of player to check
   * @returns true if player has aborted, false otherwise
   */
  hasPlayerAborted(playerIndex: number): boolean {
    if (playerIndex < 0 || playerIndex >= this.maxPlayers) {
      return false;
    }
    return this.abortedPlayers[playerIndex];
  }

  /**
   * Check if game is full
   */
  isGameFull(): boolean {
    return this.connectedPlayers >= this.maxPlayers;
  }

  /**
   * Find the index of a player by ID
   * @param playerId Player ID to find
   * @returns Player index or -1 if not found
   */
  findPlayerIndex(playerId: string): number {
    return this.players.findIndex(player => player.id === playerId);
  }

  /**
   * Find next available empty slot
   * @returns Index of empty slot or -1 if game is full
   */
  private findEmptySlot(): number {
    return this.players.findIndex(player => !player.isActive || player.id === "");
  }

  /**
   * Advance to next active player
   */
  advanceToNextActivePlayer(): void {
    // Find next active player
    let nextPlayer = (this.playerToMove + 1) % this.maxPlayers;
    
    // Loop until we find an active player or have checked all players
    const startPlayer = this.playerToMove;
    let checkedAllPlayers = false;
    
    while ((!this.players[nextPlayer].isActive || this.abortedPlayers[nextPlayer]) && !checkedAllPlayers) {
      nextPlayer = (nextPlayer + 1) % this.maxPlayers;
      
      // If we've checked all players and none are active, keep current player
      if (nextPlayer === startPlayer) {
        checkedAllPlayers = true;
        console.log(`🎮 Game ${this.id}: Checked all players, no active players found`);
        break;
      }
    }
    
    if (checkedAllPlayers) {
      // If all players are inactive, we should mark the game as finished
      console.log(`🎮 Game ${this.id}: All players are inactive, marking game as finished`);
      this.gameFinished = true;
    } else {
      console.log(`🎮 Game ${this.id}: Advanced turn from player ${this.playerToMove} to player ${nextPlayer}`);
      this.playerToMove = nextPlayer;
    }
  }

  /**
   * Set dice values
   * @param values Array of dice values
   */
  setDiceValues(values: number[]): void {
    this.diceValues = [...values];
  }

  /**
   * Convert game to JSON format
   * Returns a format compatible with the previous implementation
   */
  toJSON(): any {
    return {
      gameId: this.id,
      gameType: this.gameType,
      nrPlayers: this.maxPlayers,
      connected: this.connectedPlayers,
      playerIds: this.playerIds,
      userNames: this.userNames,
      gameStarted: this.gameStarted,
      gameFinished: this.gameFinished,
      playerToMove: this.playerToMove,
      diceValues: this.diceValues,
      abortedPlayers: this.abortedPlayers // Include aborted players in the JSON
    };
  }

  /**
   * Create a Game instance from JSON data
   * @param data JSON data
   * @returns Game instance
   */
  static fromJSON(data: any): Game {
    const game = new Game(
      data.gameId,
      data.gameType,
      data.nrPlayers
    );
    
    game.gameStarted = data.gameStarted || false;
    game.gameFinished = data.gameFinished || false;
    game.playerToMove = data.playerToMove || 0;
    game.connectedPlayers = data.connected || 0;
    game.diceValues = data.diceValues || [];
    
    // Set aborted players if available
    if (data.abortedPlayers) {
      game.abortedPlayers = [...data.abortedPlayers];
    }
    
    // Convert playerIds and userNames to players
    if (data.playerIds && data.userNames) {
      for (let i = 0; i < data.playerIds.length; i++) {
        if (data.playerIds[i]) {
          game.players[i] = PlayerFactory.createPlayer(data.playerIds[i], data.userNames[i]);
          // Mark player as inactive if they were aborted
          if (game.abortedPlayers[i]) {
            game.players[i].isActive = false;
          }
          game.playerIds[i] = data.playerIds[i]; // For backward compatibility
          game.userNames[i] = data.userNames[i]; // For backward compatibility
        }
      }
    }
    
    return game;
  }
}
