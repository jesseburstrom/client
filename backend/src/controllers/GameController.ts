import { Socket } from 'socket.io';
import { GameService } from '../services/GameService';
import { PlayerFactory } from '../models/Player';

/**
 * Controller for handling game-related socket events
 */
export class GameController {
  private gameService: GameService;

  constructor(gameService: GameService) {
    this.gameService = gameService;
  }

  /**
   * Register socket event handlers for game events
   * @param socket Socket connection
   */
  registerSocketHandlers(socket: Socket): void {
    // Request to create or join a game
    socket.on('sendToServer', (data) => {
      switch (data.action) {
        case 'requestGame':
          this.handleRequestGame(socket, data);
          break;

        case 'requestJoinGame':
          this.handleRequestJoinGame(socket, data);
          break;

        case 'removeGame':
          this.handleRemoveGame(socket, data);
          break;

        // Add other game-related actions as needed
      }
    });

    // Handle player sending dice values
    socket.on('sendToClients', (data) => {
      if (data.action === 'sendDices') {
        this.handleSendDices(socket, data);
      } else if (data.action === 'sendSelection') {
        this.handleSendSelection(socket, data);
      }
    });

    // Handle socket disconnect event
    socket.on('disconnect', () => {
      this.handleDisconnect(socket);
    });
  }

  /**
   * Handle request to create or join a game
   * @param socket Socket connection
   * @param data Request data
   */
  handleRequestGame(socket: Socket, data: any): void {
    const { gameType, nrPlayers, userName } = data;
    const player = PlayerFactory.createPlayer(socket.id, userName);

    // Use the new createOrJoinGame method which automatically handles aborting previous games
    const game = this.gameService.createOrJoinGame(gameType, nrPlayers, player);

    // For solo games, notify player immediately
    if (nrPlayers === 1) {
      // Send game start to player
      socket.emit('onServerMsg', {
        action: 'onGameStart',
        ...game.toJSON()
      });
    } else if (game.gameStarted) {
      // Game is already full and started, notify all players
      this.gameService.notifyGameUpdate(game);
    }

    // Game list is already broadcast in createOrJoinGame
  }

  /**
   * Handle request to join a specific game by ID
   * @param socket Socket connection
   * @param data Request data
   */
  handleRequestJoinGame(socket: Socket, data: any): void {
    const { gameId, userName } = data;
    const player = PlayerFactory.createPlayer(socket.id, userName);

    // Get the game
    const game = this.gameService.getGame(gameId);

    if (!game) {
      socket.emit('onServerMsg', {
        action: 'error',
        message: 'Game not found'
      });
      return;
    }

    // Try to add player to game
    if (!game.addPlayer(player)) {
      socket.emit('onServerMsg', {
        action: 'error',
        message: 'Could not join game'
      });
      return;
    }

    // If game is now full, start it
    if (game.isGameFull()) {
      game.gameStarted = true;
      this.gameService.notifyGameUpdate(game);
    }

    // Update game list for all clients
    this.gameService.broadcastGameList();
  }

  /**
   * Handle request to remove a game
   * @param socket Socket connection
   * @param data Request data
   */
  handleRemoveGame(socket: Socket, data: any): void {
    const { gameId } = data;

    // Remove the game
    this.gameService.removeGame(gameId);

    // Update game list for all clients
    this.gameService.broadcastGameList();
  }

  /**
   * Handle player sending dice values to others
   * @param socket Socket connection
   * @param data Dice data
   */
  handleSendDices(socket: Socket, data: any): void {
    const { gameId, diceValue } = data;

    // Process dice roll
    this.gameService.processDiceRoll(gameId, socket.id, diceValue);
  }

  /**
   * Handle player sending cell selection
   * @param socket Socket connection
   * @param data Selection data
   */
  handleSendSelection(socket: Socket, data: any): void {
    const { gameId, cell, player, diceValue } = data;
    
    console.log(`🎮 Player ${socket.id} selected cell ${cell} with dice values [${diceValue}]`);
    
    // Forward the selection message to all other players
    this.gameService.forwardSelectionToPlayers(gameId, socket.id, data);
    
    // Process selection for turn advancement (this also sends a game update notification)
    this.gameService.processSelection(gameId, socket.id, cell);
  }

  /**
   * Handle socket disconnect event
   * @param socket Socket that disconnected
   */
  handleDisconnect(socket: Socket): void {
    console.log(`🎮 Socket disconnected: ${socket.id}`);
    
    // Process disconnection to update all games this player was part of
    this.gameService.handlePlayerDisconnect(socket.id);
  }
}
