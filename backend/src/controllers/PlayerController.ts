import { Socket } from "socket.io";
import { GameService } from "../services/GameService";
import { PlayerFactory } from "../models/Player";

/**
 * Controller for handling player-related socket events
 */
export class PlayerController {
  private gameService: GameService;
  private playerRegistry = new Map<string, boolean>(); // Track registered players by socket ID

  constructor(gameService: GameService) {
    this.gameService = gameService;
  }

  /**
   * Register socket event handlers for player actions
   * @param socket Socket instance for the player
   */
  registerSocketHandlers(socket: Socket): void {
    // Handle all player-related actions from the client
    socket.on("sendToServer", (data) => {
      console.log(`Received message from client ${socket.id}:`, data);
      
      if (!data || typeof data !== 'object') {
        console.error('Invalid data received from client', socket.id);
        return;
      }

      switch (data.action) {
        case "getId":
          this.handleGetId(socket);
          break;
          
        case "createGame":
          this.handleCreateGame(socket, data);
          break;
          
        case "joinGame":
          this.handleJoinGame(socket, data);
          break;
          
        case "rollDice":
          this.handleRollDice(socket, data);
          break;
          
        case "selectCell":
          this.handleSelectCell(socket, data);
          break;
          
        case "requestGame":
          console.log(` [PlayerController] Forwarding requestGame action to GameController`);
          // This action should be handled by GameController, so we don't need to do anything here
          break;
          
        case "requestJoinGame":
          console.log(` [PlayerController] Forwarding requestJoinGame action to GameController`);
          // This action should be handled by GameController, so we don't need to do anything here
          break;
          
        default:
          console.log(`Unknown action: ${data.action}`);
      }
    });

    // Handle player disconnection
    socket.on('disconnect', () => {
      this.handleDisconnect(socket);
    });
  }

  /**
   * Handle player ID request
   * @param socket Socket instance for the player
   */
  private handleGetId(socket: Socket): void {
    // Check if this socket has already been assigned an ID
    if (this.playerRegistry.has(socket.id)) {
      console.log(`Player ${socket.id} already has an ID`);
      
      // Send the ID again without registering twice
      socket.emit("onServerMsg", {
        action: "getId",
        id: socket.id
      });
      
      // Also send the current games list to ensure they see all available games
      this.gameService.broadcastGameListToPlayer(socket.id);
      
      return;
    }

    // Register the player if not already registered
    this.playerRegistry.set(socket.id, true);
    console.log(`Player ${socket.id} connected and requested ID`);
    
    // Send ID to the client
    socket.emit("onServerMsg", {
      action: "getId",
      id: socket.id
    });
    
    // Also send the ID on a dedicated channel
    socket.emit("userId", socket.id);
    
    // Send the current games list to the new player
    this.gameService.broadcastGameListToPlayer(socket.id);
  }

  /**
   * Handle game creation request
   * @param socket Socket instance for the player
   * @param data Game creation data
   */
  private handleCreateGame(socket: Socket, data: any): void {
    const { gameType, nrPlayers, userName } = data;
    
    if (!gameType || !nrPlayers || !userName) {
      console.error('Invalid game creation data', data);
      return;
    }
    
    console.log(`Player ${socket.id} creating game: ${gameType}, ${nrPlayers} players`);
    
    // Create player
    const player = PlayerFactory.createPlayer(socket.id, userName);
    
    // Create game
    const game = this.gameService.createGame(gameType, nrPlayers);
    
    // Add the player to the game
    this.gameService.joinGame(game.id, player);
    
    // Notify the client
    socket.emit("onClientMsg", {
      action: "gameCreated",
      gameId: game.id
    });
  }

  /**
   * Handle game join request
   * @param socket Socket instance for the player
   * @param data Game join data
   */
  private handleJoinGame(socket: Socket, data: any): void {
    const { gameId, userName } = data;
    
    if (!gameId || !userName) {
      console.error('Invalid game join data', data);
      return;
    }
    
    console.log(`Player ${socket.id} joining game: ${gameId}`);
    
    // Create player
    const player = PlayerFactory.createPlayer(socket.id, userName);
    
    // Join game
    const joinedGame = this.gameService.joinGame(gameId, player);
    const success = joinedGame !== null;
    
    // Notify the client
    socket.emit("onClientMsg", {
      action: "gameJoined",
      gameId: gameId,
      success: success
    });
  }

  /**
   * Handle dice roll request
   * @param socket Socket instance for the player
   * @param data Dice roll data
   */
  private handleRollDice(socket: Socket, data: any): void {
    const { gameId, keepDice } = data;
    
    if (!gameId || !keepDice) {
      console.error('Invalid dice roll data', data);
      return;
    }
    
    console.log(`Player ${socket.id} rolling dice in game: ${gameId}`);
    
    // Generate random dice values (1-6) for the ones not kept
    const diceValues: number[] = [];
    for (let i = 0; i < 5; i++) {
      if (keepDice[i]) {
        // Keep existing value if available, otherwise roll new
        const game = this.gameService.getGame(gameId);
        diceValues[i] = game?.diceValues[i] || Math.floor(Math.random() * 6) + 1;
      } else {
        // Roll new value
        diceValues[i] = Math.floor(Math.random() * 6) + 1;
      }
    }
    
    // Process the roll
    const success = this.gameService.processDiceRoll(gameId, socket.id, diceValues);
    
    // Notify the client if it wasn't successful
    if (!success) {
      socket.emit("onClientMsg", {
        action: "rollFailed",
        gameId: gameId
      });
    }
  }

  /**
   * Handle cell selection request
   * @param socket Socket instance for the player
   * @param data Cell selection data
   */
  private handleSelectCell(socket: Socket, data: any): void {
    const { gameId, cellIndex } = data;
    
    if (!gameId || cellIndex === undefined) {
      console.error('Invalid cell selection data', data);
      return;
    }
    
    console.log(`Player ${socket.id} selecting cell ${cellIndex} in game: ${gameId}`);
    
    // Get the game
    const game = this.gameService.getGame(gameId);
    if (!game) {
      socket.emit("onClientMsg", {
        action: "selectFailed",
        gameId: gameId,
        reason: "Game not found"
      });
      return;
    }
    
    // Check if it's the player's turn
    const playerIndex = game.findPlayerIndex(socket.id);
    if (playerIndex === -1 || playerIndex !== game.playerToMove) {
      socket.emit("onClientMsg", {
        action: "selectFailed",
        gameId: gameId,
        reason: "Not your turn"
      });
      return;
    }
    
    // Update game state and notify players
    // This would typically involve more complex scoring logic
    
    socket.emit("onClientMsg", {
      action: "cellSelected",
      gameId: gameId,
      cellIndex: cellIndex
    });
    
    // Update all players about the game state
    this.gameService.notifyGameUpdate(game);
  }

  /**
   * Handle player disconnection
   * @param socket Socket connection
   */
  private handleDisconnect(socket: Socket): void {
    console.log(`Player ${socket.id} disconnected`);
    
    // Update games this player was in
    this.gameService.handlePlayerDisconnect(socket.id);
  }
}
