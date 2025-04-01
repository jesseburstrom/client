// backend/src/controllers/GameController.ts
import { Socket } from 'socket.io';
import { GameService } from '../services/GameService';
import { PlayerFactory, Player } from '../models/Player'; // Import Player class
import { GameLogService, GameMove } from '../services/GameLogService'; // <-- Import log service
import { getSelectionLabel } from '../utils/yatzyMapping'; // <-- Import mapping
import { Game } from '../models/Game'; // Import Game class

/**
 * Controller for handling game-related socket events
 */
export class GameController {
  private gameService: GameService;
  private gameLogService: GameLogService; // <-- Add log service instance

  constructor(gameService: GameService, gameLogService: GameLogService) { // <-- Inject log service
    this.gameService = gameService;
    this.gameLogService = gameLogService; // <-- Store log service instance
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
        case 'removeGame': // Should this be handled differently? Maybe game end.
          this.handleRemoveGame(socket, data);
          break;
        // --- Spectate Game Action ---
        case 'spectateGame':
            this.handleSpectateGame(socket, data);
            break;
        // Add other game-related actions as needed
      }
    });

    // Handle player sending dice values
    socket.on('sendToClients', (data) => {
      if (data.action === 'sendDices') {
        // Client sends dice values after rolling *itself*
        // Server should validate and maybe re-roll for security/consistency?
        // For now, trust client roll but log it.
        this.handleSendDices(socket, data);
      } else if (data.action === 'sendSelection') {
         // Client sends selection label and dice values used
        this.handleSendSelection(socket, data);
      }
    });

    // Handle socket disconnect event
    // Disconnect logging is now handled within GameService.handlePlayerDisconnect
    // socket.on('disconnect', () => {
    //   this.handleDisconnect(socket); // No longer needed here if GameService handles it
    // });
  }

  // ... (handleRequestGame, handleRequestJoinGame, handleRemoveGame remain similar, ensure they use GameService correctly)
  handleRequestGame(socket: Socket, data: any): void {
    const { gameType, nrPlayers, userName } = data;
    // --- Simplification: Validate gameType ---
    if (!['Ordinary', 'Mini', 'Maxi'].includes(gameType)) {
         console.warn(`[GameController] Invalid gameType requested: ${gameType}. Defaulting to Ordinary? Or reject.`);
         // Decide how to handle invalid type - reject or default
         // For now, reject:
         socket.emit('onServerMsg', { action: 'error', message: `Invalid game type: ${gameType}` });
         return;
    }
    // --- End Simplification ---
    const player = PlayerFactory.createPlayer(socket.id, userName, gameType); // Pass gameType

    const game = this.gameService.createOrJoinGame(gameType, nrPlayers, player);

    // GameService now handles notifications and game start logic internally
    // No need to emit 'onGameStart' here, createOrJoinGame handles it.
  }

   handleRequestJoinGame(socket: Socket, data: any): void {
     const { gameId, userName } = data;
     const game = this.gameService.getGame(gameId);

     if (!game) {
       socket.emit('onServerMsg', { action: 'error', message: 'Game not found' });
       return;
     }
     // Check if game already started or full before creating player
     if (game.gameStarted || game.isGameFull()) {
         socket.emit('onServerMsg', { action: 'error', message: 'Cannot join game (full or already started)' });
         return;
     }

     const player = PlayerFactory.createPlayer(socket.id, userName, game.gameType); // Pass gameType

     // Try to add player using the service method
     const joinedGame = this.gameService.joinGame(gameId, player);

     if (!joinedGame) {
        // This case might be redundant due to the check above, but keep for safety
        socket.emit('onServerMsg', { action: 'error', message: 'Could not join game (unexpected error)' });
     }
     // GameService.joinGame will handle starting and notifications if full
     // GameService.createOrJoinGame (called by handleRequestGame) also handles this logic now.
     // Let's ensure joinGame also triggers the necessary updates/notifications via GameService.
     else {
         // If join was successful, GameService.createOrJoinGame or similar logic should handle notifications.
         // If joinGame itself needs to trigger updates:
         this.gameService.notifyGameUpdate(joinedGame); // Send update after successful join
         if (joinedGame.gameStarted) {
             // If the join caused the game to start, send explicit start message
             const gameData = joinedGame.toJSON();
             gameData.action = 'onGameStart';
             for (const p of joinedGame.players) {
                 if (p?.isActive && p.id) {
                     this.gameService['io'].to(p.id).emit('onServerMsg', gameData); // Access io via GameService if private
                 }
             }
         }
         this.gameService.broadcastGameList(); // Ensure list is broadcast after join
     }
   }

   handleRemoveGame(socket: Socket, data: any): void {
     const { gameId } = data;
     // Check permissions? Only allow host or if game finished?
     // For now, allow removal, GameService handles broadcast.
     console.log(`-> Received request to remove game ${gameId} from ${socket.id}`);
     const game = this.gameService.getGame(gameId);
     if (game) {
         // If game exists, ensure it's properly finished and logged before removing
         if (!game.gameFinished) {
             // Force finish? Or just remove? Let's just remove for now.
             // Optionally mark as finished first
             // game.gameFinished = true;
             // this.gameService.handleGameFinished(game); // This would log and remove
         }
         this.gameService.removeGame(gameId); // removeGame now handles logging end if finished
         this.gameService.broadcastGameList(); // Broadcast handled by GameService.removeGame -> broadcastGameList
     } else {
         console.log(`-> Game ${gameId} not found for removal.`);
     }
   }


  // Modified handleSendDices to log roll via GameService
  handleSendDices(socket: Socket, data: any): void {
    const { gameId, diceValue, keptDice /* Add keptDice if sent */ } = data; // Assuming diceValue is the result of the roll
    if (gameId === undefined || !diceValue) { // Check gameId presence
        console.error("Invalid dice data received", data);
        return;
    }
    const game = this.gameService.getGame(gameId);
    if (!game) return;
    const playerIndex = game.findPlayerIndex(socket.id);
    if (playerIndex === -1 || playerIndex !== game.playerToMove) return; // Validate turn

    console.log(`🎲 Player ${socket.id} reported dice roll: [${diceValue}] for game ${gameId}`);

    // --- Logging & Processing via GameService ---
    // Note: Client calculates the roll. Server logs what client sent.
    // 'keptDice' would ideally be the state *before* this roll. Client needs to send this.
    // GameService.processDiceRoll now handles logging the 'roll' action.
    this.gameService.processDiceRoll(gameId, socket.id, diceValue, keptDice || []); // Pass empty array if keptDice not sent

    // --- Forwarding to other clients ---
    // GameService.processDiceRoll now handles broadcasting 'sendDices' via onClientMsg to others.
    // No need to forward manually here.

    // --- Send full game state update back to everyone? ---
    // Optional: Could send the full game state after processing the roll.
    // this.gameService.notifyGameUpdate(game);
  }


  // Modified handleSendSelection to use label and log via GameService
  handleSendSelection(socket: Socket, data: any): void {
    // Expect selectionLabel instead of cell index
    const { gameId, selectionLabel, player, diceValue, score /* client might send calculated score */ } = data;
     if (gameId === undefined || !selectionLabel || player === undefined || !diceValue) { // Check gameId presence
         console.error("❌ Invalid selection data received", data);
         return;
     }

     const game = this.gameService.getGame(gameId);
     if (!game) return;

     const playerIndex = game.findPlayerIndex(socket.id);
     // Validate it's the correct player's turn and the player index matches
     if (playerIndex === -1 || playerIndex !== game.playerToMove || playerIndex !== player) {
         console.warn(`⚠️ Selection ignored: Turn mismatch or player index mismatch. Got player ${player}, expected ${game.playerToMove} (socket owner index ${playerIndex})`);
         // Optionally send error back to client
         // socket.emit('onServerMsg', { action: 'error', message: 'Invalid selection attempt.' });
         return;
     }

    console.log(`🎮 Player ${socket.id} selected '${selectionLabel}' with dice [${diceValue}] score ${score ?? 'N/A'}`);

     // --- Logging & Processing via GameService ---
     // GameService now handles logging and state updates including turn advancement
     // We pass the necessary info, including the score reported by the client.
     // Server *could* recalculate score here for validation if needed.
     const success = this.gameService.processSelection(gameId, socket.id, selectionLabel, score ?? 0); // Pass score, default to 0 if not provided

     // --- Forwarding to other clients ---
     // GameService.processSelection handles notifying *all* clients via notifyGameUpdate (onServerMsg).
     // If we *also* need the specific 'sendSelection' for onClientMsg:
     if (success) {
         this.gameService.forwardSelectionToPlayers(gameId, socket.id, data); // Forward raw data for client-side processing
     }
  }

  // Removed handleDisconnect as GameService now handles it via its own listener

  /**
   * Handle spectate game request
   * @param socket Socket connection
   * @param data Request data
   */
  async handleSpectateGame(socket: Socket, data: any): Promise<void> {
    const { gameId, userName } = data;
    
    if (gameId === undefined) {
      console.error("Invalid spectate request: missing gameId", data);
      socket.emit('onServerMsg', { action: 'error', message: 'Invalid spectate request: missing gameId' });
      return;
    }

    console.log(`📊 [DEBUG] Handling spectate request for game ${gameId} from ${socket.id} (${userName || 'Anonymous'})`);

    // Get the current game from memory
    const game = this.gameService.getGame(gameId);
    if (!game) {
      console.error(`Game ${gameId} not found for spectating in active games`);
      socket.emit('onServerMsg', { action: 'error', message: 'Game not found' });
      return;
    }

    // Check if the game has started
    if (!game.gameStarted) {
      console.error(`Game ${gameId} has not started yet, cannot spectate`);
      socket.emit('onServerMsg', { action: 'error', message: 'Game has not started yet' });
      return;
    }

    // Get game log from database to ensure we have all moves
    // Important: Check both gameId and game.id as they might differ
    console.log(`📊 [DEBUG] Fetching game log from database for gameId=${gameId} and game.id=${game.id}`);
    let gameLog = await this.gameLogService.getGameLog(gameId);
    
    // If not found with the provided gameId, try with game.id (might be different)
    if (!gameLog && gameId !== game.id) {
      console.log(`📊 [DEBUG] No log found with gameId=${gameId}, trying game.id=${game.id}`);
      gameLog = await this.gameLogService.getGameLog(game.id);
    }
    
    if (gameLog) {
      console.log(`📊 [DEBUG] Found game log with ${gameLog.moves.length} moves`);
      
      // Log all selection moves for debugging
      const selectionMoves = gameLog.moves.filter(move => move.action === 'select');
      console.log(`📊 [DEBUG] Game has ${selectionMoves.length} selection moves:`);
      selectionMoves.forEach(move => {
        console.log(`📊 [DEBUG] - Player ${move.playerIndex} selected ${move.selectionLabel} for ${move.score} points`);
      });
      
      // For each selection move in the log, ensure it's applied to the game state
      console.log(`📊 [DEBUG] Ensuring all selection moves are applied to game state`);
      for (const move of selectionMoves) {
        if (move.playerIndex >= 0 && move.playerIndex < game.players.length) {
          const player = game.players[move.playerIndex];
          if (player && move.selectionLabel && move.score !== undefined) {
            console.log(`📊 [DEBUG] Applying selection "${move.selectionLabel}" with score ${move.score} to player ${move.playerIndex}`);
            
            // Use the applySelection method from Game to apply this move
            try {
              game.applySelection(move.playerIndex, move.selectionLabel, move.score);
            } catch (e) {
              console.error(`📊 [DEBUG] Error applying selection: ${e}`);
            }
          }
        }
      }
    } else {
      console.log(`📊 [DEBUG] No game log found for game ${gameId}, using in-memory state only`);
    }

    console.log(`👁️ Player ${socket.id} (${userName || 'Anonymous'}) is spectating game ${gameId}`);

    // Force recalculation of all scores for all players
    console.log(`📊 [DEBUG] Recalculating scores for all players`);
    for (const player of game.players) {
      if (player && player.isActive) {
        // Recalculate all player scores to ensure cells show current values
        player.calculateScores();
        
        // Log player score and status of key cells
        if (player.cells) {
          const foursCell = player.cells.find(c => c && c.label === 'Fours');
          const fivesCell = player.cells.find(c => c && c.label === 'Fives');
          const houseCell = player.cells.find(c => c && c.label === 'House');
          const totalCell = player.cells.find(c => c && c.label === 'Total');
          
          console.log(`📊 [DEBUG] Player ${player.username} score: ${player.score}`);
          console.log(`📊 [DEBUG] - Fours: ${foursCell ? foursCell.value : 'N/A'} (fixed: ${foursCell ? foursCell.fixed : 'N/A'})`);
          console.log(`📊 [DEBUG] - Fives: ${fivesCell ? fivesCell.value : 'N/A'} (fixed: ${fivesCell ? fivesCell.fixed : 'N/A'})`);
          console.log(`📊 [DEBUG] - House: ${houseCell ? houseCell.value : 'N/A'} (fixed: ${houseCell ? houseCell.fixed : 'N/A'})`);
          console.log(`📊 [DEBUG] - Total: ${totalCell ? totalCell.value : 'N/A'}`);
        }
      }
    }

    // Send the current game state to the spectator
    const gameData = game.toJSON();
    gameData.action = 'onGameStart';
    gameData.spectator = true; // Mark as spectator
    
    // Log detailed information about the cells being sent
    console.log(`📊 [DEBUG] Player cells in game data:`);
    game.players.forEach((player, idx) => {
      if (player && player.cells) {
        console.log(`📊 [DEBUG] Player ${idx} (${player.username}) cells:`);
        player.cells.forEach(cell => {
          if (cell) {
            console.log(`📊 [DEBUG] - ${cell.label}: value=${cell.value}, fixed=${cell.fixed}`);
          }
        });
      }
    });
    
    console.log(`📊 [DEBUG] Sending spectator data to client`);
    socket.emit('onServerMsg', gameData);

    // Log the spectate action
    this.gameLogService.logSpectate(gameId, socket.id, userName || 'Anonymous');
    
    // Also send an immediate game update message to ensure latest state
    gameData.action = 'onGameUpdate';
    console.log(`📊 [DEBUG] Sending additional update message to reinforce state`);
    socket.emit('onServerMsg', gameData);

    // Register the socket as a spectator to receive future updates
    this.gameService.addSpectator(gameId, socket.id);
  }
}