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

  callbackOnServerMsg(dynamic data) async {
    try {
      final router = getIt<AppRouter>();

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
      // --- BRANCH BASED ON MODE ---
      if (isSpectating) {
        // --- SPECTATOR LOGIC ---
        print("👁️ Processing message as Spectator. Action: $action");
        switch (action) {
          case "onGameStart": // Initial state for spectator
          case "onGameUpdate": // Subsequent updates for spectator
            // Ensure the update is for the game we are spectating
            if (data['gameId'] == spectatedGameId) {
              print(
                  "👁️ Updating spectator gameData for game $spectatedGameId.");
              gameData =
                  (data).map((key, value) => MapEntry(key.toString(), value));
              // Trigger UI refresh for SettingsView (which contains SpectatorGameBoard)
              try {
                context.read<SetStateCubit>().setState();
              } catch (e) {
                print("⚠️ Error triggering spectator UI refresh: $e");
              }
            } else {
              print(
                  "👁️ Ignoring update for different game ${data['gameId']} while spectating $spectatedGameId.");
            }
            break;
          case "onGameFinished":
            if (data['gameId'] == spectatedGameId) {
              print("👁️ Spectated game $spectatedGameId finished.");
              gameData =
                  (data).map((key, value) => MapEntry(key.toString(), value));
              // Update UI to show the final state / overlay
              try {
                context.read<SetStateCubit>().setState();
              } catch (e) {
                print("⚠️ Error triggering spectator UI refresh on finish: $e");
              }
            }
            break;
          case "onGameAborted":
            // If the spectated game is aborted, maybe stop spectating?
            if (data['gameId'] == spectatedGameId) {
              print(
                  "👁️ Spectated game $spectatedGameId was aborted. Stopping spectating.");
              isSpectating = false;
              spectatedGameId = -1;
              gameData = {};
              try {
                context.read<SetStateCubit>().setState();
              } catch (e) {
                print("⚠️ Error triggering spectator UI refresh on abort: $e");
              }
            }
            break;
          case "onRequestGames": // Spectators might still see the game list?
            print('👁️ Processing onRequestGames while spectating...');
            try {
              data = List<dynamic>.from(data["Games"]);
              games = data;
              context
                  .read<SetStateCubit>()
                  .setState(); // Update settings view if visible
            } catch (e) {
              print("⚠️ Error processing game list for spectator: $e");
            }
            break;
          // Ignore other messages not relevant to spectators? Or log them?
          default:
            print("👁️ Ignoring spectator message: $action");
        }
        // --- END SPECTATOR LOGIC ---
      } else {
        // --- PLAYER LOGIC ---
        print("▶️ Processing message as Player. Action: $action");
        switch (action) {
          case "onGetId":
            // Explicitly cast keys and values using .map()
            final Map<String, dynamic> getIdData =
                (data).map((key, value) => MapEntry(key.toString(), value));
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
            // --- Player Logic ---
            final incomingGameId = data["gameId"];

            // --- REVISED Guard against duplicate processing ---
            // Only ignore if THIS client instance has ALREADY processed the start for THIS game.
            if (gameId == incomingGameId && gameStarted && myPlayerId != -1) {
              print(
                  '🎮 Ignoring duplicate onGameStart for game $gameId because myPlayerId ($myPlayerId) is already set. incomingGameId $incomingGameId gameStarted $gameStarted');
              return; // Prevent reprocessing for this specific client instance
            }
            // --- END REVISED Guard ---

            // Check if this is a spectator message
            // if (data["spectator"] == true) {
            //   print(
            //       '👁️ Received spectator game data for game ${data["gameId"]}');
            //
            //   // Extract player data for debugging (optional, keep if useful)
            //   final players = data["players"];
            //   if (players != null && players.isNotEmpty) {
            //     final player = players[0];
            //     if (player != null && player["cells"] != null) {
            //       final cells = player["cells"];
            //       print('📊 Spectator data - player cells:');
            //       for (var cell in cells) {
            //         if (cell != null) {
            //           print(
            //               '📊 - ${cell["label"]}: value=${cell["value"]}, fixed=${cell["fixed"]}');
            //         }
            //       }
            //     }
            //   }
            //
            //   // Store the game data (Apply casting here)
            //   gameData =
            //       (data).map((key, value) => MapEntry(key.toString(), value));
            //
            //   // Apply the cell values to the UI - this is essential
            //   try {
            //     // Use the already cast `gameData` map
            //     if (gameData["players"] != null &&
            //         gameData["players"].isNotEmpty) {
            //       final player = gameData["players"][0];
            //       if (player != null && player["cells"] != null) {
            //         final cells = player["cells"];
            //         // Loop through cells and apply values to UI
            //         for (var cell in cells) {
            //           if (cell != null &&
            //               cell["value"] != null &&
            //               cell["value"] != -1 &&
            //               cell["fixed"] == true) {
            //             int index = cell["index"];
            //             if (index >= 0 && index < totalFields) {
            //               // Apply the values to the UI
            //               cellValue[0][index] = cell["value"];
            //               // Add safe checks before accessing appText
            //               if (appText.length > 1 && appText[1].length > index) {
            //                 appText[1][index] = cell["value"].toString();
            //               } else {
            //                 print(
            //                     '⚠️ Index $index out of bounds for appText[1] (${appText.length > 1 ? appText[1].length : 'N/A'})');
            //               }
            //               print(
            //                   '📊 Applied value ${cell["value"]} for ${cell["label"]} to UI');
            //             }
            //           }
            //         }
            //       }
            //     }
            //
            //     // Update the UI
            //     context.read<SetStateCubit>().setState();
            //   } catch (e) {
            //     print('⚠️ Error processing spectator data: $e');
            //   }
            //   return; // Return after handling spectator data
            // }

            // Normal game start logic (for players)
            // Find our player ID in the list
            int myIndex = -1;
            if (data["playerIds"] != null) {
              myIndex =
                  data["playerIds"].indexOf(socketService?.socketId ?? '');
            }

            // Only join if we are in this game
            if (myIndex >= 0) {
              myPlayerId = myIndex;
              // Apply casting here
              gameData =
                  (data).map((key, value) => MapEntry(key.toString(), value));
              gameId = gameData["gameId"]; // Use the casted map

              // --- Set gameStarted flag BEFORE calling setup ---
              gameStarted = true; // Mark game as started locally *before* setup

              gameType = gameData["gameType"]; // Use the casted map
              nrPlayers = gameData["nrPlayers"]; // Use the casted map
              setup();
              userNames = gameData["userNames"]; // Use the casted map
              animation.players = nrPlayers;

              print(
                  '🎮 Game started! Transitioning to game screen, myPlayerId: $myPlayerId, gameId: $gameId');

              gameStarted = true;
              await router.pushAndPopUntil(const ApplicationView(),
                  predicate: (Route<dynamic> route) => false);
            } else {
              print(
                  '🎮 Received game start for a game we\'re not in: ${data["gameId"]}');
            }
            break;
          case "onRequestGames":
            // --- Add Check: Only process if not currently in a game ---
            // This prevents the game list update from interfering right after starting a game.
            // It assumes the user sees the list primarily from the SettingsView.
            // If (gameId == -1 && !gameStarted) { // Only update list if not in an active game
            print('📩 Processing onRequestGames...');
            data = List<dynamic>.from(data["Games"]);
            games = data;
            context
                .read<SetStateCubit>()
                .setState(); // Update settings view if visible
            break;
          case "onGameUpdate":
            _processGameUpdate(data);
            break;
          case "onGameAborted":
            print('🚪 Received onGameAborted');
            // Reset state and go back to settings
            gameId = -1;
            myPlayerId = -1;
            isSpectating = false; // Ensure spectator mode is also reset
            spectatedGameId = -1;
            gameData = {};
            context.read<SetStateCubit>().setState();
            await router.pushAndPopUntil(const SettingsView(),
                predicate: (_) => false);
            break;
          case "onGameFinished":
            print(
                '🏁 Received onGameFinished from server for game ${data["gameId"]}');
            final Map<String, dynamic> finishedGameData =
                (data).map((key, value) => MapEntry(key.toString(), value));
            gameData = finishedGameData;
            // Trigger UI update first
            context.read<SetStateCubit>().setState();

            // Player specific logic (dialog is handled by UI layer)
            print('🏁 Game finished for player. UI layer will handle dialog.');

            // **** Trigger top score fetch for THIS game type ****
            try {
              if (socketService != null && socketService!.isConnected) {
                final finishedGameType = gameData['gameType'] ??
                    gameType; // Get type from finished game data or current app state
                print(
                    '🏆 Requesting latest top scores for $finishedGameType after game finish...');
                socketService!.sendToServer({
                  'action': 'requestTopScores',
                  'gameType': finishedGameType
                });
              } else {
                print(
                    '⚠️ Cannot request top scores: SocketService not connected.');
              }
            } catch (e) {
              print('❌ Error sending requestTopScores for player: $e');
            }

            break;
          case "onTopScoresUpdate":
            print('🏆 Received top scores update');
            try {
              // Parse received data
              final Map<String, dynamic> receivedData =
                  (data).map((key, value) => MapEntry(key.toString(), value));
              final receivedGameType = receivedData['gameType'];
              final dynamic scoresList = receivedData['scores'];

              // Validate format
              if (receivedGameType == null ||
                  receivedGameType is! String ||
                  scoresList == null ||
                  scoresList is! List) {
                print('❌ Invalid onTopScoresUpdate data format: $receivedData');
                return;
              }

              // Convert score entries to the correct type
              List<Map<String, dynamic>> typedScores = (scoresList)
                  .map((scoreEntry) {
                    if (scoreEntry is Map) {
                      return scoreEntry
                          .map((k, v) => MapEntry(k.toString(), v));
                    } else {
                      print(
                          '⚠️ Unexpected score entry format for $receivedGameType: $scoreEntry');
                      return <String, dynamic>{};
                    }
                  })
                  .where((map) => map.isNotEmpty)
                  .toList();

              // **** CALL NEW TopScore METHOD ****
              // Update the TopScore instance directly instead of app state
              topScore.updateScoresFromData(
                  typedScores, context.read<SetStateCubit>());
              print(
                  '🏆 Updated TopScore instance for $receivedGameType (${typedScores.length} entries)');

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
      }
    } catch (e) {
      print('🎮 Error processing server message: $e');
    }
  }

  // Helper method to process game updates
  void _processGameUpdate(dynamic data) async {
    try {
      print('🎮 Processing game update: $data'); // Log action

      // If this is a different game from what we're playing, ignore it
      if (data["gameId"] != gameId && gameId != -1) {
        print(
            '🎮 Ignoring update for different game ID: ${data["gameId"]} (our gameId: $gameId)');
        return;
      }

      // Update game data with the new information
      gameData = data;

      // If the game hasn't started yet, don't do anything more
      if (!(data["gameStarted"] ?? false)) {
        print('🎮 Game ${data["gameId"]} hasn\'t started yet');
        return;
      }

      if (data["playerIds"] != null) {
        final newPlayerIds = data["playerIds"];

        List<dynamic> playersData = gameData['players'];
        playerActive = (gameData['abortedPlayers'] as List<dynamic>)
            .map((e) => !(e as bool))
            .toList();

        // --- Update cell state for each player ---
        for (int p = 0; p < playersData.length; p++) {
          var playerData = playersData[p];
          if (playerData?['cells'] is List) {
            List<dynamic> cellsData = playerData['cells'];
            for (int c = 0; c < cellsData.length; c++) {
              // Skip if cell index is out of bounds for local arrays
              if (c >= totalFields ||
                  p >= fixedCell.length ||
                  c >= fixedCell[p].length ||
                  p >= cellValue.length ||
                  c >= cellValue[p].length ||
                  p + 1 >= appText.length ||
                  c >= appText[p + 1].length ||
                  p + 1 >= appColors.length ||
                  c >= appColors[p + 1].length) {
                print("continue");
                continue;
              }

              var cellData = cellsData[c];

              if (cellData != null) {
                try {
                  final bool serverFixed = cellData['fixed'] ?? false;
                  final int serverValue = cellData['value'] ?? -1;

                  // --- Apply server state directly to local state ---
                  fixedCell[p][c] = serverFixed;
                  cellValue[p][c] = serverValue;
                  appText[p + 1][c] =
                      serverValue != -1 ? serverValue.toString() : "";
                } catch (e) {
                  print("❌ Error updating cell state [$p][$c]: $e");
                }
              }
            }
          }
        }
        updateBoardColors();
        // ****** END: CORE STATE SYNCHRONIZATION ******

        // Check if this is our first update and we don't have an ID yet
        if (gameId == -1) {
          int potentialId = newPlayerIds.indexOf(socketService?.socketId ?? '');
          if (potentialId >= 0) {
            // We found ourselves in this game
            myPlayerId = potentialId;
            gameId = data["gameId"];
            gameType = data["gameType"];
            nrPlayers = data["nrPlayers"];
            setup();
            userNames = data["userNames"];
            animation.players = nrPlayers;

            print('🎮 Joining game $gameId as player $myPlayerId');

            return;
          }
        }

        // Check if the current player is still in the game
        if (myPlayerId >= 0 && myPlayerId < newPlayerIds.length) {
          String myId = socketService?.socketId ?? '';

          if (newPlayerIds[myPlayerId] == null ||
              newPlayerIds[myPlayerId].isEmpty ||
              (newPlayerIds[myPlayerId] != myId)) {
            print(
                '🎮 WARNING: Our player appears to have been removed from the game');
            // We've been removed from the game - we should not process this update
            return;
          }
        }
      }

      // Handle player turn changes
      final newPlayerToMove = data["playerToMove"];
      print(
          'playerToMove $playerToMove newPlayerToMove $newPlayerToMove dicevalue0 ${data["diceValues"][0]}');
      if (newPlayerToMove != playerToMove || data["diceValues"][0] == 0) {
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
      // *** Update Dice State from Server ***
      if (gameData['diceValues'] != null && gameData['diceValues'] is List) {
        try {
          final List<int> serverDiceValues =
              List<int>.from(gameData['diceValues']);
          final int serverRollCount =
              gameData['rollCount'] ?? app.gameDices.nrRolls; // Get roll count

          print(
              "🎲 Server update: Syncing dice to ${serverDiceValues}, roll count to $serverRollCount");
          app.gameDices.diceValue = serverDiceValues;
          app.gameDices.nrRolls = serverRollCount; // <-- Update roll count too!

          // Update visual representation
          app.gameDices.updateDiceImages(); // For 2D dice
          if (app.gameDices.unityDices && app.gameDices.unityCreated) {
            app.gameDices.sendDicesToUnity(); // For 3D dice
          }
        } catch (e) {
          print("⚠️ Error processing diceValues from server: $e");
        }
      }
      // **********************************
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

    chat.scrollController.animateTo(
        chat.scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.fastOutSlowIn);

    print('💬 Sending chat message to game $gameId');

    // Use the modern SocketService if available
    if (socketService != null && socketService!.isConnected) {
      print('💬 Using modern SocketService to send chat message');

      // Create message for modern SocketService
      final msg = {
        "action": "chatMessage",
        "gameId": gameId,
        "message": text,
        "sender": userName,
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
          if (selectionPlayer >= 0 &&
              selectionPlayer < playerActive.length &&
              !playerActive[selectionPlayer]) {
            print(
                '🎲 Ignoring selection from inactive/aborted player $selectionPlayer');
            return;
          }

          // Check if the selection is for the current player (that's us) making a selection
          // or if it's from another player that we need to update on our board
          if (data["player"] != myPlayerId) {
            print(
                '🎲 Updating board with selection from player ${data["player"]}');

            // Update dice values to show what the other player had
            gameDices.diceValue = data["diceValue"].cast<int>();

            // Mark the cell as selected but don't change turns
            // Actual turn change will come via the onGameUpdate message
            int player = data["player"];

            // Get next player (same logic as in calcNewSums)
            int nextPlayer = player;
            do {
              nextPlayer = (nextPlayer + 1) % nrPlayers;
            } while (!playerActive[nextPlayer]);
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
