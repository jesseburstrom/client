import 'package:flutter/material.dart';

import '../models/game.dart';
import '../models/player.dart';
import '../models/board_cell.dart';
import 'socket_service.dart';

/// Service responsible for managing game logic and state
class GameService {
  /// Socket service for network communication
  final SocketService socketService;
  
  /// Current game instance
  Game? _game;
  
  /// Callbacks for game events
  final Function(Game)? onGameUpdated;
  final Function(String)? onError;
  
  /// Creates a new GameService instance
  GameService({
    required this.socketService,
    this.onGameUpdated,
    this.onError,
  }) {
    // Register for game updates from socket service
    socketService.onGameUpdate = _handleGameUpdate;
  }
  
  /// Get the current game
  Game? get game => _game;
  
  /// Handle game update from socket service
  void _handleGameUpdate(Game updatedGame) {
    _game = updatedGame;
    
    if (onGameUpdated != null) {
      onGameUpdated!(_game!);
    }
  }
  
  /// Create a new game
  void createGame({
    required String gameType,
    required int maxPlayers,
    required String username,
  }) {
    socketService.createGame(
      gameType: gameType,
      maxPlayers: maxPlayers,
      username: username,
    );
  }
  
  /// Join an existing game
  void joinGame({
    required int gameId,
    required String username,
  }) {
    socketService.joinGame(
      gameId: gameId,
      username: username,
    );
  }
  
  /// Roll dice
  void rollDice({List<bool>? keepDice}) {
    if (_game == null) {
      _reportError('No active game');
      return;
    }
    
    if (!_game!.isMyTurn) {
      _reportError('Not your turn');
      return;
    }
    
    if (!_game!.canRoll) {
      _reportError('Cannot roll again');
      return;
    }
    
    // If keepDice not provided, assume no dice are kept
    final diceToKeep = keepDice ?? List.filled(5, false);
    
    socketService.rollDice(
      gameId: _game!.gameId,
      keepDice: diceToKeep,
    );
  }
  
  /// Calculate possible scores for a cell
  int calculateScoreForCell(BoardCell cell, List<int> diceValues) {
    if (_game == null || diceValues.length != 5) {
      return 0;
    }
    
    // Sort dice values for easier calculations
    final sortedDice = List<int>.from(diceValues)..sort();
    
    // Get cell index and label
    final cellIndex = cell.index;
    final cellLabel = cell.label.toLowerCase();
    
    // Upper section (ones through sixes)
    if (cellIndex >= 0 && cellIndex <= 5) {
      final targetValue = cellIndex + 1;
      return sortedDice.where((value) => value == targetValue).fold(0, (sum, value) => sum + value);
    }
    
    // Lower section
    switch (cellLabel) {
      case 'pair':
        return _calculatePairScore(sortedDice);
      
      case 'two pairs':
        return _calculateTwoPairsScore(sortedDice);
        
      case 'three of a kind':
        return _calculateThreeOfAKindScore(sortedDice);
        
      case 'four of a kind':
        return _calculateFourOfAKindScore(sortedDice);
        
      case 'house':
      case 'full house':
        return _calculateFullHouseScore(sortedDice);
        
      case 'small straight':
        return _calculateSmallStraightScore(sortedDice);
        
      case 'large straight':
        return _calculateLargeStraightScore(sortedDice);
        
      case 'chance':
        return sortedDice.fold(0, (sum, value) => sum + value);
        
      case 'yatzy':
      case 'maxi yatzy':
        return _calculateYatzyScore(sortedDice);
        
      default:
        return 0;
    }
  }
  
  /// Select a cell for scoring
  void selectCell(int cellIndex) {
    if (_game == null) {
      _reportError('No active game');
      return;
    }
    
    if (!_game!.isMyTurn) {
      _reportError('Not your turn');
      return;
    }
    
    // Check if the selected cell is valid
    final player = _game!.myPlayer;
    if (cellIndex < 0 || cellIndex >= player.cells.length) {
      _reportError('Invalid cell index');
      return;
    }
    
    final cell = player.cells[cellIndex];
    if (cell.fixed) {
      _reportError('Cell already fixed');
      return;
    }
    
    // Calculate possible score
    final diceValues = _game!.diceValues;
    final possibleScore = calculateScoreForCell(cell, diceValues);
    
    // Update cell value with possible score
    cell.value = possibleScore;
    
    // Send selection to server
    socketService.selectCell(
      gameId: _game!.gameId,
      cellIndex: cellIndex,
    );
  }
  
  /// Report an error
  void _reportError(String message) {
    if (onError != null) {
      onError!(message);
    }
  }
  
  // Score calculation helper methods
  
  /// Calculate score for pair
  int _calculatePairScore(List<int> sortedDice) {
    // Look for the highest pair
    for (int i = 4; i > 0; i--) {
      if (sortedDice[i] == sortedDice[i - 1]) {
        return sortedDice[i] * 2;
      }
    }
    return 0;
  }
  
  /// Calculate score for two pairs
  int _calculateTwoPairsScore(List<int> sortedDice) {
    int pairCount = 0;
    int score = 0;
    
    // Find pairs from highest to lowest
    for (int i = 4; i > 0; i--) {
      if (sortedDice[i] == sortedDice[i - 1]) {
        pairCount++;
        score += sortedDice[i] * 2;
        i--; // Skip the second die in the pair
      }
    }
    
    return pairCount >= 2 ? score : 0;
  }
  
  /// Calculate score for three of a kind
  int _calculateThreeOfAKindScore(List<int> sortedDice) {
    for (int i = 0; i <= 2; i++) {
      if (sortedDice[i] == sortedDice[i + 1] && sortedDice[i] == sortedDice[i + 2]) {
        return sortedDice[i] * 3;
      }
    }
    return 0;
  }
  
  /// Calculate score for four of a kind
  int _calculateFourOfAKindScore(List<int> sortedDice) {
    for (int i = 0; i <= 1; i++) {
      if (sortedDice[i] == sortedDice[i + 1] && 
          sortedDice[i] == sortedDice[i + 2] &&
          sortedDice[i] == sortedDice[i + 3]) {
        return sortedDice[i] * 4;
      }
    }
    return 0;
  }
  
  /// Calculate score for full house
  int _calculateFullHouseScore(List<int> sortedDice) {
    // Check if we have three of a kind + pair
    bool hasThreeOfAKind = false;
    bool hasPair = false;
    int threeOfAKindValue = 0;
    int pairValue = 0;
    
    // Check for three of a kind at the beginning
    if (sortedDice[0] == sortedDice[1] && sortedDice[1] == sortedDice[2]) {
      hasThreeOfAKind = true;
      threeOfAKindValue = sortedDice[0];
      
      // Check for pair at the end
      if (sortedDice[3] == sortedDice[4] && sortedDice[3] != threeOfAKindValue) {
        hasPair = true;
        pairValue = sortedDice[3];
      }
    } 
    // Check for three of a kind at the end
    else if (sortedDice[2] == sortedDice[3] && sortedDice[3] == sortedDice[4]) {
      hasThreeOfAKind = true;
      threeOfAKindValue = sortedDice[2];
      
      // Check for pair at the beginning
      if (sortedDice[0] == sortedDice[1] && sortedDice[0] != threeOfAKindValue) {
        hasPair = true;
        pairValue = sortedDice[0];
      }
    }
    
    return (hasThreeOfAKind && hasPair) ? (threeOfAKindValue * 3 + pairValue * 2) : 0;
  }
  
  /// Calculate score for small straight
  int _calculateSmallStraightScore(List<int> sortedDice) {
    // Small straight is 1-2-3-4-5
    if (sortedDice[0] == 1 && sortedDice[1] == 2 && 
        sortedDice[2] == 3 && sortedDice[3] == 4 && 
        sortedDice[4] == 5) {
      return 15; // Sum of 1+2+3+4+5
    }
    return 0;
  }
  
  /// Calculate score for large straight
  int _calculateLargeStraightScore(List<int> sortedDice) {
    // Large straight is 2-3-4-5-6
    if (sortedDice[0] == 2 && sortedDice[1] == 3 && 
        sortedDice[2] == 4 && sortedDice[3] == 5 && 
        sortedDice[4] == 6) {
      return 20; // Sum of 2+3+4+5+6
    }
    return 0;
  }
  
  /// Calculate score for Yatzy
  int _calculateYatzyScore(List<int> sortedDice) {
    // All five dice showing the same face
    if (sortedDice[0] == sortedDice[4]) {
      return 50; // Standard score for Yatzy
    }
    return 0;
  }
}
