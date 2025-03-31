import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yatzy/application/application_functions_internal.dart';
import 'package:yatzy/dices/unity_communication.dart';

import '../chat/chat.dart';
import '../injection.dart';
import '../router/router.dart';
import '../router/router.gr.dart';
import '../services/service_provider.dart';
import '../shared_preferences.dart';
import '../startup.dart';
import '../states/cubit/state/state_cubit.dart';
import 'application.dart';

extension CommunicationApplication on Application {
  // Helper method to reset dice state when turn changes
  void resetDices() {
    // Clear dice display
    gameDices.clearDices();
    
    // Reset temporary dice values
    for (var i = 0; i < totalFields; i++) {
      if (playerToMove < nrPlayers && !fixedCell[playerToMove][i]) {
        appText[playerToMove + 1][i] = "";
        cellValue[playerToMove][i] = -1;
      }
    }
    
    // Clear focus
    clearFocus();
  }

  handlePlayerAbort(int abortedPlayerIndex) {
    print('🎮 Handling player abort for player $abortedPlayerIndex');

    // Mark player as inactive
    playerActive[abortedPlayerIndex] = false;

    // Mark their column as inactive (dark)
    for (var j = 0; j < totalFields; j++) {
      appColors[abortedPlayerIndex + 1][j] = Colors.black.withValues(alpha: 0.5);
    }

    // If the aborted player was the current player to move, advance to the next active player
    if (abortedPlayerIndex == playerToMove) {
      advanceToNextActivePlayer();
    }

    // Update the board colors
    colorBoard();

    // Send a notification to the console for debugging
    print('🎮 Player $abortedPlayerIndex has aborted the game, adjusted game state accordingly');
  }

  advanceToNextActivePlayer() {
    print('🎮 Advancing to next active player from current player $playerToMove');

    // Safety check
    if (playerActive.isEmpty) return;

    final startingPlayer = playerToMove;
    
    do {
      playerToMove = (playerToMove + 1) % nrPlayers;

      // If we've checked all players and none are active, keep current player
      if (playerToMove == startingPlayer) {
        print('🎮 All players are inactive or we\'ve checked all players');
        break;
      }
    } while (!playerActive[playerToMove]);

    print('🎮 Advanced to next active player: $playerToMove');

    // Update the board colors to show the current player
    colorBoard();
    
    // Reset dice for the new player
    resetDices();

    if (myPlayerId == playerToMove) {
      print('🎮 My turn now, enabling dice throw');
      if (gameDices.unityDices) {
        gameDices.sendResetToUnity();
        gameDices.sendStartToUnity();
      }
    }
  }

  callbackOnServerMsg(dynamic data) async {
    try {
      final router = getIt<AppRouter>();
      print('📩 Received server message: $data');

      // *** ADD NULL CHECK FOR data ***
      if (data == null || data is! Map) {
        print('⚠️ Received invalid server message data: $data');
        return;
      }

      // *** Safely access action ***
      final action = data['action'];
      if (action == null) {
        print('⚠️ Server message missing \'action\' key: $data');
        return;
      }

      switch (action) {
        case "onGetId":
          // Explicitly cast keys and values using .map()
          final Map<String, dynamic> getIdData = (data as Map).map(
            (key, value) => MapEntry(key.toString(), value)
          );
          try {
            final serviceProvider = ServiceProvider.of(context);
            serviceProvider.socketService.socketId = getIdData["id"];
          } catch (e) {
            print('⚠️ ServiceProvider not available in onGetId: $e');
          }
          var settings = SharedPrefProvider.fetchPrefObject('yatzySettings');
          if (settings.length > 0) {
             userName = settings["userName"];
             gameType = settings["gameType"];
             nrPlayers = settings["nrPlayers"];
             boardAnimation = settings["boardAnimation"];
             chosenLanguage = settings["language"];
             gameDices.unityDices = settings["unityDices"];
             gameDices.unityLightMotion = settings["unityLightMotion"];
          }
          break;
        case "onGameStart":
          print('🎮 Received game start event for game ${data["gameId"]}');
          
          // Check if this is a spectator message
          if (data["spectator"] == true) {
            print('👁️ Received spectator game data for game ${data["gameId"]}');
            
            // Extract player data for debugging (optional, keep if useful)
            final players = data["players"];
            if (players != null && players.isNotEmpty) {
              final player = players[0];
              if (player != null && player["cells"] != null) {
                final cells = player["cells"];
                print('📊 Spectator data - player cells:');
                for (var cell in cells) {
                  if (cell != null) {
                    print('📊 - ${cell["label"]}: value=${cell["value"]}, fixed=${cell["fixed"]}');
                  }
                }
              }
            }
            
            // Store the game data (Apply casting here)
            gameData = (data).map((key, value) => MapEntry(key.toString(), value));
            
            // Apply the cell values to the UI - this is essential
            try {
              // Use the already cast `gameData` map
              if (gameData["players"] != null && gameData["players"].isNotEmpty) {
                final player = gameData["players"][0];
                if (player != null && player["cells"] != null) {
                  final cells = player["cells"];
                  // Loop through cells and apply values to UI
                  for (var cell in cells) {
                    if (cell != null && cell["value"] != null && cell["value"] != -1 && cell["fixed"] == true) {
                      int index = cell["index"];
                      if (index >= 0 && index < totalFields) {
                        // Apply the values to the UI
                        cellValue[0][index] = cell["value"];
                        // Add safe checks before accessing appText
                        if (appText.length > 1 && appText[1].length > index) {
                           appText[1][index] = cell["value"].toString();
                        } else {
                           print('⚠️ Index $index out of bounds for appText[1] (${appText.length > 1 ? appText[1].length : 'N/A'})');
                        }
                        print('📊 Applied value ${cell["value"]} for ${cell["label"]} to UI');
                      }
                    }
                  }
                }
              }
              
              // Update the UI
              context.read<SetStateCubit>().setState();
            } catch (e) {
              print('⚠️ Error processing spectator data: $e');
            }
            return; // Return after handling spectator data
          }
          
          // Normal game start logic (for players)
          // Find our player ID in the list
          int myIndex = -1;
          if (data["playerIds"] != null) {
            myIndex = data["playerIds"].indexOf(socketService?.socketId ?? '');
          }
          
          // Only join if we are in this game
          if (myIndex >= 0) {
            // Check if this is a game we're already in - if so, treat it as an update
            if (gameId == data["gameId"] && gameId != -1) {
              print('🎮 Received onGameStart for our current game - treating as update');
              // Process this as a game update instead of a new game
              // Apply casting here too for consistency
              _processGameUpdate((data as Map).map((key, value) => MapEntry(key.toString(), value)));
              return;
            }
            
            myPlayerId = myIndex;
            // Apply casting here
            gameData = (data as Map).map((key, value) => MapEntry(key.toString(), value));
            gameId = gameData["gameId"]; // Use the casted map
            playerIds = gameData["playerIds"]; // Use the casted map
            playerActive = List.filled(playerIds.length, true);
            gameType = gameData["gameType"]; // Use the casted map
            nrPlayers = gameData["nrPlayers"]; // Use the casted map
            setup();
            userNames = gameData["userNames"]; // Use the casted map
            animation.players = nrPlayers;
            
            print('🎮 Game started! Transitioning to game screen, myPlayerId: $myPlayerId, gameId: $gameId');
            
            if (applicationStarted) {
              if (gameDices.unityCreated) {
                gameDices.sendResetToUnity();
                if (gameDices.unityDices && myPlayerId == playerToMove) {
                  gameDices.sendStartToUnity();
                }
              }
              await router.pop();
            } else {
              applicationStarted = true;
              await router.pushAndPopUntil(const ApplicationView(),
                  predicate: (Route<dynamic> route) => false);
            }
          } else {
            print('🎮 Received game start for a game we\'re not in: ${data["gameId"]}');
          }
          break;
        case "onRequestGames":
          data = List<dynamic>.from(data["Games"]);
          games = data;
          _checkIfPlayerAborted();
          break;
        case "onGameUpdate":
          _processGameUpdate(data);
          break;
        case "onGameAborted":
          print('🚪 Received onGameAborted');
          // Reset state and go back to settings
          gameId = -1;
          myPlayerId = -1;
          gameFinished = false;
          isSpectating = false; // Ensure spectator mode is also reset
          spectatedGameId = -1;
          gameData = {};
          context.read<SetStateCubit>().setState();
          await router.pushAndPopUntil(const SettingsView(), predicate: (_) => false);
          break;
        case "onGameFinished":
          print('🏁 Received onGameFinished from server for game ${data["gameId"]}');
          final Map<String, dynamic> finishedGameData = (data).map(
            (key, value) => MapEntry(key.toString(), value)
          );
          gameData = finishedGameData;
          gameFinished = true; // Set flag for UI layer to handle dialog

          // Trigger UI update first
          context.read<SetStateCubit>().setState();

          if (!isSpectating) {
            // Player specific logic (dialog is handled by UI layer)
            print('🏁 Game finished for player. UI layer will handle dialog.');
            
            // **** Trigger top score fetch for THIS game type ****
            try {
               if (socketService != null && socketService!.isConnected) {
                   final finishedGameType = gameData['gameType'] ?? gameType; // Get type from finished game data or current app state
                   print('🏆 Requesting latest top scores for $finishedGameType after game finish...');
                   socketService!.sendToServer({
                     'action': 'requestTopScores',
                     'gameType': finishedGameType 
                    });
               } else {
                   print('⚠️ Cannot request top scores: SocketService not connected.');
               }
            } catch (e) {
               print('❌ Error sending requestTopScores for player: $e');
            }

          } else {
             // Spectator specific logic - DO NOTHING related to top scores
             print('🏁 Spectator received game finished signal.');
          }
          break;
        case "onTopScoresUpdate":
          print('🏆 Received top scores update');
          try {
            // Parse received data
            final Map<String, dynamic> receivedData = (data as Map).map(
              (key, value) => MapEntry(key.toString(), value)
            );
            final receivedGameType = receivedData['gameType'];
            final dynamic scoresList = receivedData['scores'];

            // Validate format
            if (receivedGameType == null || receivedGameType is! String || scoresList == null || scoresList is! List) {
               print('❌ Invalid onTopScoresUpdate data format: $receivedData');
               return;
            }

            // Convert score entries to the correct type
            List<Map<String, dynamic>> typedScores = (scoresList as List).map((scoreEntry) {
              if (scoreEntry is Map) {
                return scoreEntry.map((k, v) => MapEntry(k.toString(), v));
              } else {
                print('⚠️ Unexpected score entry format for $receivedGameType: $scoreEntry');
                return <String, dynamic>{};
              }
            }).where((map) => map.isNotEmpty).toList();

            // **** CALL NEW TopScore METHOD ****
            // Update the TopScore instance directly instead of app state
            topScore.updateScoresFromData(typedScores, context.read<SetStateCubit>());
            print('🏆 Updated TopScore instance for $receivedGameType (${typedScores.length} entries)');

            // Remove update to app.currentTopScores
            // currentTopScores = typedScores;
            // print('🏆 Updated local top scores for $receivedGameType (${currentTopScores.length} entries)');

            // Remove direct setState call here, as updateScoresFromData handles it
            // context.read<SetStateCubit>().setState();

          } catch (e) {
            print('❌ Error processing top scores update: $e');
            print('Raw data causing error: $data');
          }
          break;
      }
    } catch (e) {
      print('🎮 Error processing server message: $e');
    }
  }
  
  // Helper method to check if any players have aborted the game
  void _checkIfPlayerAborted() {
    // **** ADD THIS GUARD ****
    if (isSpectating || gameData.isEmpty || gameId == -1) {
      print('🎮 Skipping _checkIfPlayerAborted (Spectating or no active game data)');
      return;
    }
    // **** END GUARD ****

    // Existing logic...
    print('🎮 Checking for aborted players...'); // Add log

    // Track if any player's status changed
    bool playerStatusChanged = false;

    for (var i = 0; i < games.length; i++) {
      // Ensure games[i] is a Map and has the required keys
      if (games[i] is Map && games[i]["gameId"] == gameData["gameId"] && games[i]["playerIds"] != null) {
        var currentGameFromList = games[i]; // To avoid repeated lookups

        // Ensure playerActive and playerIds are initialized and match length
        if (playerActive.length != nrPlayers || playerIds.length != nrPlayers) {
           print('⚠️ Player state arrays mismatch nrPlayers ($nrPlayers). Reinitializing.');
           playerActive = List.filled(nrPlayers, true); // Reinitialize based on current game
           playerIds = List<String>.from(gameData['playerIds'] ?? List.filled(nrPlayers, "")); // Use current game data
        }


        for (var j = 0; j < nrPlayers && j < currentGameFromList["playerIds"].length; j++) {
          // Make sure indices are valid before accessing
          if (j < playerActive.length) {
             bool wasActive = playerActive[j];
             // Check if player ID is present and not empty in the game list data
             bool isActive = currentGameFromList["playerIds"][j] != null &&
                             currentGameFromList["playerIds"][j].toString().isNotEmpty;

             // If a player was active but is now inactive, they aborted
             if (wasActive && !isActive) {
               print('🎮 Player $j has aborted the game!');
               playerStatusChanged = true;
               handlePlayerAbort(j); // Make sure this function handles UI updates
             }

             // Update the local playerActive status
             playerActive[j] = isActive;
          } else {
             print('⚠️ Index $j out of bounds for playerActive (${playerActive.length})');
          }
        }
         // Update playerIds safely
         playerIds = List<String>.from(currentGameFromList["playerIds"]);
         break; // Found the matching game, no need to check others
      }
    }

    // If no specific player status changed but current player is inactive,
    // we need to advance to the next active player
    // Add checks to prevent RangeError here as well
    if (!playerStatusChanged &&
        playerToMove >= 0 && playerToMove < playerActive.length && !playerActive[playerToMove]) {
      _advanceToNextActivePlayer();
    } else if (playerToMove >= playerActive.length) {
       print('⚠️ playerToMove ($playerToMove) is out of bounds for playerActive (${playerActive.length})');
       // Reset playerToMove? Or handle error?
       if (playerActive.isNotEmpty) playerToMove = 0;
    }

    // Update board colors based on the potentially changed playerActive status
    colorBoard(); // Moved from inside the loop

    // Trigger UI update if needed (e.g., if handlePlayerAbort doesn't do it)
    if (playerStatusChanged) {
        try {
            context.read<SetStateCubit>().setState();
        } catch (e) { print('⚠️ Error updating state after abort check: $e'); }
    }
  }
  
  // Helper method to advance to the next active player
  void _advanceToNextActivePlayer() {
    print('🎮 Current player $playerToMove is inactive, advancing to next active player');
    
    // Clear unfixed cells of the current player before advancing
    for (var j = 0; j < totalFields; j++) {
      if (!fixedCell[playerToMove][j]) {
        cellValue[playerToMove][j] = -1;
        appText[playerToMove + 1][j] = "";
      }
    }
    
    // Find the next active player
    int nextPlayer = playerToMove;
    bool foundActivePlayer = false;
    
    // Try to find an active player by checking each player in order
    for (int i = 0; i < nrPlayers; i++) {
      nextPlayer = (nextPlayer + 1) % nrPlayers;
      if (playerActive[nextPlayer]) {
        foundActivePlayer = true;
        break;
      }
    }
    
    if (foundActivePlayer) {
      print('🎮 Found next active player: $nextPlayer');
      playerToMove = nextPlayer;
      
      // Reset dice for the new player
      resetDices();
      
      // If it's my turn, start dice rolling
      if (playerToMove == myPlayerId) {
        print('🎮 My turn now! Enabling dice throw');
        if (gameDices.unityDices) {
          gameDices.sendResetToUnity();
          gameDices.sendStartToUnity();
        }
      }
    } else {
      print('🎮 No active players found, game cannot continue');
    }
  }
  
  // Helper method to process game updates
  void _processGameUpdate(dynamic data) async {
    try {
      final router = getIt<AppRouter>();
      print('🎮 Processing game update: $data');

      // Check if we're in spectator mode
      bool isSpectator = data["spectator"] == true;
      
      // If spectator, we need to handle things differently
      if (isSpectator) {
        print('👁️ Processing game update as spectator');
        
        try {
          // Make a deep copy of the data to ensure all parts are updated
          Map<String, dynamic> newGameData = Map<String, dynamic>.from(data);
          
          // Log complete data for debugging
          print('👁️ COMPLETE SPECTATOR DATA: $newGameData');
          print('👁️ Received new spectator data with keys: ${newGameData.keys.join(', ')}');
          
          // Get direct board data if available
          if (newGameData['cellValue'] != null) {
            print('👁️ Found direct cellValue data: ${newGameData['cellValue']}');
          }
          
          if (newGameData['appText'] != null) {
            print('👁️ Found appText data: ${newGameData['appText']}');
          }
          
          if (newGameData['appColors'] != null) {
            print('👁️ Found appColors data (length): ${newGameData['appColors'].length}');
          }
          
          // Check for dice values - multiple possible formats
          if (newGameData['diceValues'] != null) {
            print('👁️ Dice values: ${newGameData['diceValues']}');
          } else if (newGameData['diceValue'] != null) {
            print('👁️ Dice value: ${newGameData['diceValue']}');
            // Standardize naming
            newGameData['diceValues'] = newGameData['diceValue'];
          }
          
          // Try to extract dice data from other places
          if (newGameData['gameDices'] != null && newGameData['gameDices']['diceValue'] != null) {
            newGameData['diceValues'] = newGameData['gameDices']['diceValue'];
            print('👁️ Found dice values in gameDices: ${newGameData['diceValues']}');
          }
          
          // Check for player data
          if (newGameData['players'] != null && newGameData['players'].isNotEmpty) {
            print('👁️ Found ${newGameData['players'].length} players in data');
            
            // Debug first player data
            var player = newGameData['players'][0];
            if (player != null) {
              print('👁️ First player data keys: ${player.keys.join(', ')}');
              
              // Check for score data in various formats
              if (player['scoreSheet'] != null) {
                print('👁️ Found scoreSheet: ${player['scoreSheet']}');
              } else if (player['cells'] != null) {
                print('👁️ Found cells array with ${player['cells'].length} items');
                
                // Try to construct a scoreSheet from cells if needed
                if (player['scoreSheet'] == null) {
                  Map<String, dynamic> scoreSheet = {};
                  for (var cell in player['cells']) {
                    if (cell != null && cell['key'] != null && cell['value'] != null) {
                      scoreSheet[cell['key']] = cell['value'];
                    }
                  }
                  
                  if (scoreSheet.isNotEmpty) {
                    player['scoreSheet'] = scoreSheet;
                    print('👁️ Created scoreSheet from cells: $scoreSheet');
                  }
                }
              }
            }
          }
          
          // Check if we need to populate data from cellValue
          if (newGameData['cellValue'] != null && newGameData['players'] == null) {
            try {
              // Try to create player structures from cellValue
              List<Map<String, dynamic>> players = [];
              for (int i = 0; i < newGameData['cellValue'].length; i++) {
                Map<String, dynamic> scoreSheet = {};
                
                // List of score keys in order
                List<String> scoreKeys = [
                  'ones', 'twos', 'threes', 'fours', 'fives', 'sixes',
                  'upperSum', 'bonus', 'pair', 'twoPairs', 'threeOfAKind',
                  'fourOfAKind', 'fullHouse', 'smallStraight', 'largeStraight',
                  'chance', 'yatzy', 'total'
                ];
                
                for (int j = 0; j < scoreKeys.length && j < newGameData['cellValue'][i].length; j++) {
                  if (newGameData['cellValue'][i][j] != null && newGameData['cellValue'][i][j] != -1) {
                    scoreSheet[scoreKeys[j]] = newGameData['cellValue'][i][j];
                  }
                }
                
                Map<String, dynamic> player = {
                  'name': newGameData['userNames']?[i] ?? 'Player ${i+1}',
                  'scoreSheet': scoreSheet
                };
                
                players.add(player);
              }
              
              if (players.isNotEmpty) {
                newGameData['players'] = players;
                print('👁️ Created players from cellValue: ${players.length} players');
              }
            } catch (e) {
              print('👁️ Error creating players from cellValue: $e');
            }
          }
          
          // Check for player names in various formats
          if (newGameData['userNames'] != null) {
            print('👁️ User names: ${newGameData['userNames']}');
          }
          
          // Update the game data with the new information
          gameData = newGameData;
          
          // Make sure to update the UI state to refresh the spectator view
          // We use Future.microtask to ensure the UI update happens in the next event loop
          // This helps avoid potential state inconsistencies

            try {
              print('👁️ Updating spectator UI state...');
              context.read<SetStateCubit>().setState();
              print('👁️ Updated spectator UI state successfully');
            } catch (e) {
              print('⚠️ Error updating spectator UI state: $e');
            }

        } catch (parseError) {
          print('⚠️ Error parsing spectator data: $parseError');
          // Still try to update with the raw data
          gameData = data;
          context.read<SetStateCubit>().setState();
        }
        
        // Since we're just a spectator, we don't need to navigate or setup the game
        return;
      }

      // Normal player processing starts here
      
      // If this is a different game from what we're playing, ignore it
      if (data["gameId"] != gameId && gameId != -1) {
        print('🎮 Ignoring update for different game ID: ${data["gameId"]} (our gameId: $gameId)');
        return;
      }

      // Update game data with the new information
      gameData = data;
      
      // If the game hasn't started yet, don't do anything more
      if (!(data["gameStarted"] ?? false)) {
        print('🎮 Game ${data["gameId"]} hasn\'t started yet');
        return;
      }

      // Check if the player list has changed - someone might have disconnected
      if (data["playerIds"] != null) {
        final newPlayerIds = data["playerIds"];

        // Check if this is our first update and we don't have an ID yet
        if (gameId == -1) {
          int potentialId = newPlayerIds.indexOf(socketService?.socketId ?? '');
          if (potentialId >= 0) {
            // We found ourselves in this game
            myPlayerId = potentialId;
            gameId = data["gameId"];
            playerIds = data["playerIds"];
            playerActive = List.filled(playerIds.length, true);
            gameType = data["gameType"];
            nrPlayers = data["nrPlayers"];
            setup();
            userNames = data["userNames"];
            animation.players = nrPlayers;
            
            print('🎮 Joining game $gameId as player $myPlayerId');
            
            if (applicationStarted) {
              if (gameDices.unityCreated) {
                gameDices.sendResetToUnity();
                if (gameDices.unityDices && myPlayerId == playerToMove) {
                  gameDices.sendStartToUnity();
                }
              }
              await router.pop();
            } else {
              applicationStarted = true;
              await router.pushAndPopUntil(const ApplicationView(),
                  predicate: (Route<dynamic> route) => false);
            }
            return;
          }
        }

        // Make sure playerIds and playerActive are initialized
        if (playerIds.isEmpty) {
          playerIds = List<String>.from(newPlayerIds);
          playerActive = List.filled(playerIds.length, true);
        }

        // Check if the current player is still in the game
        if (myPlayerId >= 0 && myPlayerId < newPlayerIds.length) {
          String myId = socketService?.socketId ?? '';

          if (newPlayerIds[myPlayerId] == null || 
              newPlayerIds[myPlayerId].isEmpty ||
              (newPlayerIds[myPlayerId] != myId)) {
            print('🎮 WARNING: Our player appears to have been removed from the game');
            // We've been removed from the game - we should not process this update
            return;
          }
        }

        // Process player status changes if arrays are initialized
        if (playerIds.isNotEmpty && playerActive.isNotEmpty) {
          bool playerStatusChanged = false;
          for (int i = 0; i < playerIds.length && i < playerActive.length; i++) {
            if (i < newPlayerIds.length) {
              bool wasActive = playerActive[i];
              bool isActive = newPlayerIds[i] != null && newPlayerIds[i].toString().isNotEmpty;

              // Player was active but is now inactive (aborted/disconnected)
              if (wasActive && !isActive) {
                print('🎮 Player $i has aborted/disconnected!');
                handlePlayerAbort(i);
                playerStatusChanged = true;
              }
            }
          }
        }

        // Update playerIds safely
        playerIds = List<String>.from(newPlayerIds);
      }

      // Handle player turn changes
      final newPlayerToMove = data["playerToMove"];
      if (newPlayerToMove != null && newPlayerToMove != playerToMove) {
        playerToMove = newPlayerToMove;
        print('🎮 Turn changed to player $playerToMove (my ID: $myPlayerId)');
        
        // Reset dice for the new player's turn
        resetDices();
        
        // If it's my turn, start dice rolling
        if (playerToMove == myPlayerId) {
          print('🎮 My turn now! Enabling dice throw');
          if (gameDices.unityDices) {
            gameDices.sendResetToUnity();
            gameDices.sendStartToUnity();
          }
        }
      }
      
      // Always update board colors
      colorBoard();
    } catch (e) {
      print('🎮 Error processing game update: $e');
    }
  }

  chatCallbackOnSubmitted(String text) {
    print('💬 Chat message submitted: "$text"');
    
    // Don't send empty messages
    if (text.trim().isEmpty) {
      print('💬 Ignoring empty chat message');
      return;
    }
    
    // Get the current game ID
    final gameId = this.gameId;
    
    // Format the message with the username
    final formattedMessage = "$userName: $text";

    chat.scrollController.animateTo(
      chat.scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 400),
      curve: Curves.fastOutSlowIn
    );
    
    print('💬 Sending chat message to game $gameId with players: $playerIds');
    
    // Use the modern SocketService if available
    if (socketService != null && socketService!.isConnected) {
      print('💬 Using modern SocketService to send chat message');
      
      // Create message for modern SocketService
      final msg = {
        "action": "chatMessage",
        "gameId": gameId,
        "message": text,
        "sender": userName,
        "playerIds": playerIds,
      };
      
      // Send via the modern socket service
      socketService!.sendToClients(msg);
    }
  }

  updateChat(String text) async {
    chat.messages.add(ChatMessage(text, "receiver"));

    await Future.delayed(const Duration(milliseconds: 100), () {});
    chat.scrollController.animateTo(
        chat.scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.fastOutSlowIn);
  }

  callbackOnClientMsg(var data) async {
    try {
      final router = getIt<AppRouter>();
      switch (data["action"]) {
        case "sendSelection":
          print('🎲 Received selection from player: ${data["player"]}');

          // Check if this is a selection from a player that aborted
          // If the selection is from a player that's no longer active, ignore it
          int selectionPlayer = data["player"];
          if (selectionPlayer >= 0 && selectionPlayer < playerActive.length && !playerActive[selectionPlayer]) {
            print('🎲 Ignoring selection from inactive/aborted player $selectionPlayer');
            return;
          }

          // Check if the selection is for the current player (that's us) making a selection
          // or if it's from another player that we need to update on our board
          if (data["player"] != myPlayerId) {
            print('🎲 Updating board with selection from player ${data["player"]}');

            // Update dice values to show what the other player had
            gameDices.diceValue = data["diceValue"].cast<int>();
            updateDiceValues();

            // Mark the cell as selected but don't change turns
            // Actual turn change will come via the onGameUpdate message
            int player = data["player"];
            int cell = data["cell"];

            // Update the cell appearance and call calcNewSums
            appColors[player + 1][cell] = Colors.green.withValues(alpha: 0.7);
            fixedCell[player][cell] = true;
            
            // Clear unfixed cells for the current player
            for (var i = 0; i < totalFields; i++) {
              if (!fixedCell[player][i]) {
                appText[player + 1][i] = "";
                cellValue[player][i] = -1;
              }
            }
            applyLocalSelection(player, cell, cellValue[player][cell]);

            // Get next player (same logic as in calcNewSums)
            int nextPlayer = player;
            do {
              nextPlayer = (nextPlayer + 1) % nrPlayers;
            } while (!playerActive[nextPlayer]);
            
            // Clear unfixed cells for the next player
            for (var i = 0; i < totalFields; i++) {
              if (!fixedCell[nextPlayer][i]) {
                appText[nextPlayer + 1][i] = "";
                cellValue[nextPlayer][i] = -1;
              }
            }

            // Clear dice visuals
            gameDices.clearDices();
          } else {
            // This is our own selection coming back to us, we can ignore it
            // since we already processed it locally
            print('🎲 Ignoring selection from myself (player $myPlayerId)');
          }
          break;
        case "sendDices":
          data = Map<String, dynamic>.from(data);
          var dices = data["diceValue"].cast<int>();
          if (dices[0] == 0) {
            resetDices();
          } else {
            gameDices.diceValue = dices;
            updateDiceValues();
            gameDices.nrRolls += 1;
            gameDices.updateDiceImages();
            if (gameDices.unityDices) {
              gameDices.sendDicesToUnity();
            }
          }
          break;
        case "chatMessage":
          updateChat(data["chatMessage"]);
          break;
        case "onGameAborted":
          await router.push(const SettingsView());
          break;
      }
    } catch (e) {
      print('🎮 Error processing client message: $e');
    }
  }
}