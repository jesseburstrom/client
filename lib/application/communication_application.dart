import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:yatzy/application/application_functions_internal.dart';
import 'package:yatzy/dices/unity_communication.dart';

import '../chat/chat.dart';
import '../injection.dart';
import '../router/router.dart';
import '../router/router.gr.dart';
import '../shared_preferences.dart';
import '../startup.dart';
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

      switch (data["action"]) {
        case "onGetId":
          data = Map<String, dynamic>.from(data);
          net.socketConnectionId = data["id"];

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
          data = Map<String, dynamic>.from(data);
          
          // Find our player ID in the list
          int myIndex = -1;
          if (data["playerIds"] != null) {
            myIndex = data["playerIds"].indexOf(socketService?.socketId ?? net.socketConnectionId);
          }
          
          // Only join if we are in this game
          if (myIndex >= 0) {
            // Check if this is a game we're already in - if so, treat it as an update
            if (gameId == data["gameId"] && gameId != -1) {
              print('🎮 Received onGameStart for our current game - treating as update');
              // Process this as a game update instead of a new game
              _processGameUpdate(data);
              return;
            }
            
            myPlayerId = myIndex;
            gameData = data;
            gameId = data["gameId"];
            playerIds = data["playerIds"];
            playerActive = List.filled(playerIds.length, true);
            gameType = data["gameType"];
            nrPlayers = data["nrPlayers"];
            setup();
            userNames = data["userNames"];
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
          await router.push(const SettingsView());
          break;
      }
    } catch (e) {
      print('🎮 Error processing server message: $e');
    }
  }
  
  // Helper method to check if any players have aborted the game
  void _checkIfPlayerAborted() {
    if (gameData.isEmpty) {
      return;
    }

    // Track if any player's status changed
    bool playerStatusChanged = false;

    for (var i = 0; i < games.length; i++) {
      if (games[i]["gameId"] == gameData["gameId"]) {
        for (var j = 0; j < nrPlayers && j < games[i]["playerIds"].length; j++) {
          bool wasActive = playerActive[j];
          bool isActive = games[i]["playerIds"][j] != null && games[i]["playerIds"][j] != "";

          // If a player was active but is now inactive, they aborted
          if (wasActive && !isActive) {
            print('🎮 Player $j has aborted the game!');
            playerStatusChanged = true;
            handlePlayerAbort(j);
          }

          playerActive[j] = isActive;
        }
        playerIds = games[i]["playerIds"];
      }
    }

    // If no specific player status changed but current player is inactive,
    // we need to advance to the next active player
    if (!playerStatusChanged && playerToMove < playerActive.length && !playerActive[playerToMove]) {
      _advanceToNextActivePlayer();
    }

    colorBoard();
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
          int potentialId = newPlayerIds.indexOf(socketService?.socketId ?? net.socketConnectionId);
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
            
            print('🎮 Joining game ${gameId} as player $myPlayerId');
            
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

        // Check if the current player is still in the game
        if (myPlayerId >= 0 && myPlayerId < newPlayerIds.length) {
          String myId = socketService?.socketId ?? net.socketConnectionId;
          
          if (newPlayerIds[myPlayerId] == null || 
              newPlayerIds[myPlayerId].isEmpty ||
              (newPlayerIds[myPlayerId] != myId)) {
            print('🎮 WARNING: Our player appears to have been removed from the game');
            // We've been removed from the game - we should not process this update
            return;
          }
        }

        // Process player status changes
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

            // Update the cell appearance but don't call calcNewSums
            appColors[player + 1][cell] = Colors.green.withValues(alpha: 0.7);
            fixedCell[player][cell] = true;
            
            // Clear unfixed cells for the current player
            for (var i = 0; i < totalFields; i++) {
              if (!fixedCell[player][i]) {
                appText[player + 1][i] = "";
                cellValue[player][i] = -1;
              }
            }
            
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
