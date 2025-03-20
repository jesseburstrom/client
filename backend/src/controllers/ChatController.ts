import { Socket, Server } from 'socket.io';
import { GameService } from '../services/GameService';

/**
 * Controller for handling chat-related socket events
 */
export class ChatController {
  private io: Server;
  private gameService: GameService;

  constructor(io: Server, gameService?: GameService) {
    this.io = io;
    this.gameService = gameService;
  }

  /**
   * Register socket event handlers for chat events
   * @param socket Socket connection
   */
  registerSocketHandlers(socket: Socket): void {
    console.log(`💬 Registering chat handlers for socket ${socket.id}`);
    
    // Handle chat messages from sendToClients
    socket.on('sendToClients', (data) => {
      if (data.action === 'chatMessage') {
        console.log(`💬 Chat message received via sendToClients from ${socket.id}:`, data);
        this.handleChatMessage(socket, data);
      }
    });
    
    // Handle chat messages from sendToServer
    socket.on('sendToServer', (data) => {
      if (data.action === 'chatMessage') {
        console.log(`💬 Chat message received via sendToServer from ${socket.id}:`, data);
        this.handleServerChatMessage(socket, data);
      }
    });
  }

  /**
   * Handle chat message from player via sendToClients
   * @param socket Socket connection
   * @param data Chat message data
   */
  private handleChatMessage(socket: Socket, data: any): void {
    // Extract data based on format (support both legacy and modern formats)
    const chatMessage = data.chatMessage;
    const playerIds = data.playerIds;
    const gameId = data.gameId;
    const message = data.message;
    const sender = data.sender;
    
    console.log(`💬 Received chat message from ${socket.id}:`, {
      format: chatMessage ? 'legacy' : 'modern',
      chatMessage,
      gameId,
      message,
      sender,
      playerIds: playerIds?.length
    });
    
    // Handle modern format (gameId + message + sender)
    if (gameId !== undefined && message !== undefined) {
      // Format message if needed
      const formattedMessage = sender ? `${sender}: ${message}` : message;
      
      console.log(`💬 Processing modern chat format: ${formattedMessage} for game ${gameId}`);
      
      // Use the GameService to find all players in the game
      if (this.gameService) {
        const game = this.gameService.getGame(gameId);
        
        if (game) {
          console.log(`💬 Found game ${gameId} with ${game.players.length} players`);
          
          // Send to all active players EXCEPT the sender
          for (const player of game.players) {
            // Skip the sender - CRITICAL to avoid echoing messages back
            if (player.id === socket.id) {
              console.log(`💬 Skipping message sender ${socket.id}`);
              continue;
            }
            
            if (player.isActive && player.id) {
              console.log(`💬 Sending chat message to player ${player.id} in game ${gameId}`);
              this.io.to(player.id).emit('onClientMsg', {
                action: 'chatMessage',
                chatMessage: formattedMessage
              });
            }
          }
          return;
        } else {
          console.log(`💬 Could not find game with ID ${gameId}, falling back to playerIds`);
        }
      }
    }
    
    // Handle legacy format (chatMessage + playerIds)
    if (chatMessage && playerIds && Array.isArray(playerIds)) {
      console.log(`💬 Processing legacy chat format with ${playerIds.length} recipient(s)`);
      
      // Forward message to all players except sender
      for (const playerId of playerIds) {
        // Skip the sender - CRITICAL to avoid echoing messages back
        if (playerId === socket.id) {
          console.log(`💬 Skipping message sender ${socket.id}`);
          continue;
        }
        
        if (playerId) {
          console.log(`💬 Sending chat message to player ${playerId}`);
          this.io.to(playerId).emit('onClientMsg', {
            action: 'chatMessage',
            chatMessage
          });
        }
      }
    } else {
      console.log(`💬 Invalid chat message format, missing required fields`);
    }
  }
  
  /**
   * Handle chat message from player via sendToServer
   * This version supports the newer format with gameId and message properties
   * @param socket Socket connection
   * @param data Chat message data
   */
  private handleServerChatMessage(socket: Socket, data: any): void {
    const { gameId, message, sender } = data;
    
    console.log(`💬 Processing server chat message from ${socket.id}:`, { gameId, message, sender });
    
    if (!message) {
      console.log(`💬 Ignoring invalid chat message from ${socket.id} - missing message`);
      return;
    }
    
    if (!gameId) {
      console.log(`💬 Ignoring invalid chat message from ${socket.id} - missing gameId`);
      return;
    }
    
    // Format the chat message
    const chatMessage = sender ? `${sender}: ${message}` : message;
    
    // Use the GameService to find all players in the game
    if (this.gameService) {
      const game = this.gameService.getGame(gameId);
      
      if (game) {
        console.log(`💬 Found game ${gameId} with ${game.players.length} players`);
        
        // Send to all active players except the sender
        for (const player of game.players) {
          if (player.isActive && player.id && player.id !== socket.id) {
            console.log(`💬 Sending chat message to player ${player.id} in game ${gameId}`);
            this.io.to(player.id).emit('onClientMsg', {
              action: 'chatMessage',
              chatMessage
            });
          }
        }
      } else {
        console.log(`💬 Could not find game with ID ${gameId}`);
      }
    } else {
      console.log(`💬 GameService not available, broadcasting to all sockets in room`);
      
      // If GameService is not available, broadcast to all in the room
      socket.to(`game_${gameId}`).emit('onClientMsg', {
        action: 'chatMessage',
        chatMessage
      });
    }
  }
  
  /**
   * Broadcast chat message to all players in the same game as the sender
   * Used as a fallback when specific playerIds are not provided
   * @param socket Socket connection
   * @param data Chat message data
   */
  private broadcastToPlayersInSameGame(socket: Socket, data: any): void {
    if (!this.gameService) {
      console.log(`💬 GameService not available, cannot find player's game`);
      return;
    }
    
    // Find all games that this player is in
    const playerGames = [];
    
    // Use the getAllGames method to find games with this player
    this.gameService.getAllGames().forEach(game => {
      if (game.players.some(player => player.id === socket.id && player.isActive)) {
        playerGames.push(game);
      }
    });
    
    if (playerGames.length === 0) {
      console.log(`💬 Player ${socket.id} is not in any active games`);
      return;
    }
    
    console.log(`💬 Player ${socket.id} is in ${playerGames.length} active games`);
    
    // For each game, broadcast to all other active players
    for (const game of playerGames) {
      console.log(`💬 Broadcasting to all players in game ${game.id}`);
      
      const chatMessage = data.chatMessage;
      
      for (const player of game.players) {
        if (player.isActive && player.id && player.id !== socket.id) {
          console.log(`💬 Sending chat message to player ${player.id} in game ${game.id}`);
          this.io.to(player.id).emit('onClientMsg', {
            action: 'chatMessage',
            chatMessage
          });
        }
      }
    }
  }
}
