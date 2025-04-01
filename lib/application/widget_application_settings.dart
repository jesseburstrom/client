import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yatzy/dices/unity_communication.dart';
import '../router/router.gr.dart';
import '../services/service_provider.dart';
import '../shared_preferences.dart';
import '../startup.dart';
import '../states/bloc/language/language_bloc.dart';
import '../states/bloc/language/language_event.dart';
import '../states/cubit/state/state_cubit.dart';
import '../widgets/spectator_game_board.dart';
import 'application.dart';

extension WidgetApplicationSettings on Application {
  List<Widget> widgetWaitingGame(BuildContext context) {
    List<Widget> gameWidgets = [];

    var ongoingGames = 0;
    for (var i = 0; i < games.length; i++) {
      if (!games[i]["gameStarted"]) {
        var gameTypeText = games[i]["gameType"];
        if (gameTypeText == "Ordinary") {
          gameTypeText = gameTypeOrdinary_;
        }
        var gameText = '$gameTypeText ${games[i]["connected"]}/${games[i]["nrPlayers"]} ${games[i]["userNames"]}';
        try {
          final serviceProvider = ServiceProvider.of(context);
          if (games[i]["playerIds"].indexOf(serviceProvider.socketService.socketId) == -1) {
            gameWidgets.add(inputItems.widgetButton(
                () => onAttemptJoinGame(context, i), gameText));
          } else {
            gameWidgets.add(Text(gameText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.black87,
                )));
          }
        } catch (e) {
          print('⚠️ ServiceProvider not available in widgetWaitingGame: $e');
          // Add button without checking socket ID
          gameWidgets.add(inputItems.widgetButton(
              () => onAttemptJoinGame(context, i), gameText));
        }
      } else {
        // This is an ongoing game - add a spectate button
        ongoingGames++;
        var gameTypeText = games[i]["gameType"];
        if (gameTypeText == "Ordinary") {
          gameTypeText = gameTypeOrdinary_;
        }
        var gameText = '$gameTypeText ${games[i]["connected"]}/${games[i]["nrPlayers"]} ${games[i]["userNames"]} (Ongoing)';
        
        // Add spectate button
        gameWidgets.add(inputItems.widgetButton(
            () => onSpectateGame(context, games[i]["gameId"]), gameText));
      }
    }
    gameWidgets.add(Text("$ongoingGames_ : $ongoingGames",
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 20,
          color: Colors.brown,
        )));
    return gameWidgets;
  }

  // Method to handle spectating a game
  onSpectateGame(BuildContext context, int gameId) async {
    print('🎮 Attempting to spectate game: $gameId');

    try {
      final serviceProvider = ServiceProvider.of(context);

      // Create a message to request spectating
      Map<String, dynamic> msg = {
        "action": "spectateGame",
        "gameId": gameId,
        "userName": userName // Send username for logging/display?
      };

      // Send the spectate request
      if (serviceProvider.socketService.isConnected) {
        print('🎮 Sending spectate request via socket service');

        // *** SET FLAG BEFORE sending request/setState ***
        isSpectating = true;
        spectatedGameId = gameId;
        gameData = {}; // Clear previous game data immediately

        serviceProvider.socketService.sendToServer(msg);

        // *** Update the UI AFTER setting the flags ***
        context.read<SetStateCubit>().setState(); // Update UI to show spectator board

        // Show a snackbar to indicate spectating has started
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('👁️ Spectating game #$gameId...'),
            duration: const Duration(seconds: 3),
          ),
        );

      } else {
        print('❌ Cannot spectate: Not connected to server');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot spectate: Not connected')),
        );
      }
    } catch (e) {
      print('⚠️ ServiceProvider not available in onSpectateGame: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error starting spectator mode')),
      );
      // Handle offline mode or show error
    }
  }

  onAttemptJoinGame(BuildContext context, int i) {
    Map<String, dynamic> msg = {};

    msg = games[i];

    msg["userName"] = userName;
    msg["action"] = "requestJoinGame";

    // Send the join game request
    print('🎮 Joining multiplayer game: ${msg["gameType"]} (${msg["nrPlayers"]} players)');

    // Get the service provider
    try {
      final serviceProvider = ServiceProvider.of(context);
      final socketServiceConnected = serviceProvider.socketService.isConnected;

      // Always use the modern SocketService if it's connected
      if (socketServiceConnected) {
        print('🎮 Using modern SocketService for joining game');
        serviceProvider.socketService.sendToServer(msg);
      }
    } catch (e) {
      print('⚠️ ServiceProvider not available in onAttemptJoinGame: $e');
      // Handle offline mode or show error
    }
  }

  // --- Simplified Game Type Selection ---
  Widget _buildGameTypeSelection(Function state) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.blue.shade50,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                Text("Game Type", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), // Use headingStyle if available
                const SizedBox(height: 8),
                inputItems.widgetStringRadioButton( // Use widgetStringRadioButton
                    state,
                    [ // Simplified list of values
                      "Mini",
                      "Ordinary",
                      "Maxi",
                    ],
                    [ // Simplified list of translations
                      gameTypeMini_,
                      gameTypeOrdinary_,
                      gameTypeMaxi_,
                    ],
                        (x) => {gameType = x},
                    gameType),
              ],
            ),
          ),
        ),
      ),
    );
  }
  // --- End Simplified Game Type Selection ---
  onStartGameButton(BuildContext context, Function state) async {
    try {
      final serviceProvider = ServiceProvider.of(context);
      final socketServiceConnected = serviceProvider.socketService.isConnected;

      if (socketServiceConnected) {
        Map<String, dynamic> msg = {};

        msg = {};
        msg["playerIds"] = List.filled(nrPlayers, "");
        msg["userNames"] = List.filled(nrPlayers, "");
        msg["userName"] = userName;
        msg["gameType"] = gameType;
        msg["nrPlayers"] = nrPlayers;
        msg["connected"] = 0;
        msg["gameStarted"] = false;
        msg["action"] = "requestGame";

        // Send through the active socket connection
        print('🎮 Creating multiplayer game with $nrPlayers players');

        // Always use the modern SocketService if it's connected
        if (socketServiceConnected) {
          print('🎮 Using modern SocketService for game creation');
          serviceProvider.socketService.sendToServer(msg);
        }

        state();

        msg = {};
        msg["action"] = "saveSettings";
        msg["userName"] = userName;
        msg["gameType"] = gameType;
        msg["nrPlayers"] = nrPlayers;
        msg["language"] = chosenLanguage;
        msg["boardAnimation"] = boardAnimation;
        msg["unityDices"] = gameDices.unityDices;
        msg["unityLightMotion"] = gameDices.unityLightMotion;
        SharedPrefProvider.setPrefObject('yatzySettings', msg);
      } else {
        print('❌ No socket connection - starting offline 1-player game');
        myPlayerId = 0;
        gameId = 0;
        playerIds = [""];
        playerActive = List.filled(playerIds.length, true);
        nrPlayers = 1;

        setup();
        userNames = [userName];
        animation.players = 1;
        if (applicationStarted) {
          if (gameDices.unityDices) {
            gameDices.sendResetToUnity();
            if (gameDices.unityDices && myPlayerId == playerToMove) {
              gameDices.sendStartToUnity();
            }
          }

          context.read<SetStateCubit>().setState();
          AutoRouter.of(context).pop();
        } else {
          applicationStarted = true;
          await AutoRouter.of(context).pushAndPopUntil(const ApplicationView(),
              predicate: (Route<dynamic> route) => false);
        }
      }
    } catch (e) {
      print('⚠️ ServiceProvider not available in onStartGameButton: $e');
      // Start offline game
      print('❌ No service provider - starting offline 1-player game');
      myPlayerId = 0;
      gameId = 0;
      playerIds = [""];
      playerActive = List.filled(playerIds.length, true);
      nrPlayers = 1;

      setup();
      userNames = [userName];
      animation.players = 1;
      if (applicationStarted) {
        if (gameDices.unityDices) {
          gameDices.sendResetToUnity();
          if (gameDices.unityDices && myPlayerId == playerToMove) {
            gameDices.sendStartToUnity();
          }
        }

        context.read<SetStateCubit>().setState();
        AutoRouter.of(context).pop();
      } else {
        applicationStarted = true;
        await AutoRouter.of(context).pushAndPopUntil(const ApplicationView(),
            predicate: (Route<dynamic> route) => false);
      }
    }
  }

  onChangeUserName(value) {
    userName = textEditingController.text;
  }

  // **** Updated Widget to use topScore instance ****
  Widget _buildTopScoresWidget() {
    // Read data directly from the global topScore instance
    if (topScore.topScores.isEmpty) { // Assuming the internal list is named topScores
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: Text("Top Scores for current game type will appear here...")),
      );
    }

    List<Widget> scoreWidgets = [];
    // Add header using the current gameType
    scoreWidgets.add(
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: Text(
          'Top Scores: $gameType', // Use app.gameType for the header
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
        ),
      )
    );

    // Limit display to top N scores
    int count = 0;
    // Iterate through the list in the topScore instance
    for (var scoreEntry in topScore.topScores) { 
      if (count >= 10) break; // Limit to top 10
      
      // Ensure scoreEntry is a Map before accessing keys
      if (scoreEntry is Map) {
          scoreWidgets.add(
            ListTile(
              dense: true,
              leading: Text('${count + 1}.', style: const TextStyle(fontWeight: FontWeight.bold)),
              title: Text('${scoreEntry['name'] ?? 'Unknown'}'),
              trailing: Text('${scoreEntry['score'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.bold)),
            )
          );
          count++;
      } else {
          print("⚠️ Invalid score entry format in topScore.topScores: $scoreEntry");
      }
    }
    
    // Add padding at the bottom
    scoreWidgets.add(const SizedBox(height: 10));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: scoreWidgets,
    );
  }
  // **** END UPDATED WIDGET ****

  Widget widgetScaffoldSettings(BuildContext context, Function state) {
    // Define a consistent color scheme for better visibility
    final primaryColor = Colors.blue.shade700; // Brighter primary color
    final accentColor = Theme.of(context).colorScheme.secondary;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    const tabTextStyle = TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: Colors.white, // Ensure high contrast for tab text
    );

    final headingStyle = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.bold,
      color: Theme.of(context).colorScheme.onSurface,
    );

    final subtitleStyle = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w500,
      color: Theme.of(context).colorScheme.onSurface,
    );

    return DefaultTabController(
        length: tabController.length,
        child: Scaffold(
            appBar: AppBar(
              backgroundColor: primaryColor, // Explicitly set app bar color
              title: Text(
                settings_,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white, // High contrast white text
                  fontSize: 24,
                ),
              ),
              elevation: 4,
              bottom: TabBar(
                controller: tabController,
                isScrollable: false,
                indicatorWeight: 3,
                indicatorColor: Colors.white, // High contrast indicator
                labelColor: Colors.white, // Ensure high contrast for selected tab
                unselectedLabelColor: Colors.white.withOpacity(0.8), // Still visible unselected tabs
                tabs: [
                  Tab(child: Text(game_, style: tabTextStyle)),
                  Tab(child: Text(general_, style: tabTextStyle)),
                ],
              ),
            ),
            body: TabBarView(
              controller: tabController,
              children: [
                // Game Settings Tab
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.blue.shade50,
                        Colors.white,
                      ],
                    ),
                  ),
                  child: Scrollbar(
                    child: ListView(
                        primary: true,
                        children: <Widget>[
                          // --- Use the simplified game type selection ---
                          _buildGameTypeSelection(state),
                          // --- End simplified game type selection ---
                              // Number of Players Selection
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                child: Card(
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  // Add decorative patterns to card
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomLeft,
                                        end: Alignment.topRight,
                                        colors: [
                                          Colors.white,
                                          Colors.blue.shade50,
                                        ],
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        children: [
                                          Text("Number of Players", style: headingStyle),
                                          const SizedBox(height: 8),
                                          inputItems.widgetIntRadioButton(
                                              state,
                                              ["1", "2", "3", "4"],
                                              (x) => {nrPlayers = x},
                                              nrPlayers),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // Username Input
                              Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Card(
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  // Add decorative patterns to card
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      gradient: LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          Colors.white,
                                          Colors.blue.shade50,
                                        ],
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        children: [
                                          Text("Player Name", style: headingStyle),
                                          const SizedBox(height: 8),
                                          Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  currentUsername_ + userName.toString(),
                                                  style: subtitleStyle,
                                                ),
                                                const SizedBox(width: 10),
                                                SizedBox(
                                                    width: 150,
                                                    height: 40,
                                                    child: inputItems.widgetInputText(
                                                        enterUsername_,
                                                        (x) => {onChangeUserName(x), state()},
                                                        (x) => {onChangeUserName(x), state()},
                                                        textEditingController,
                                                        focusNode)),
                                              ]),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // Start Game Button - centered with appropriate width
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24.0,
                                  vertical: 8.0,
                                ),
                                child: Center(
                                  child: ElevatedButton(
                                    onPressed: () => onStartGameButton(context, state),
                                    style: ElevatedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      backgroundColor: Colors.green.shade700,
                                      minimumSize: const Size(200, 60), // Regular sized button
                                      padding: const EdgeInsets.symmetric(horizontal: 32),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 8,
                                    ),
                                    child: Text(
                                      createGame_,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ] +
                            // Available Games List
                            widgetWaitingGame(context) +
                            // **** ADD Top Scores Section ****
                            [ 
                              const SizedBox(height: 20), // Add some spacing
                              _buildTopScoresWidget(),
                              const SizedBox(height: 20), // Add some spacing
                            ] +
                            // Spectator View (if active)
                            (isSpectating ? [
                              // Full-screen spectator view
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: MediaQuery.of(context).size.height * 0.7, // 70% of screen height
                                  maxHeight: MediaQuery.of(context).size.height * 0.85, // 85% of screen height
                                ),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.blue.shade300),
                                    borderRadius: BorderRadius.circular(8.0),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        spreadRadius: 1,
                                        blurRadius: 3,
                                        offset: const Offset(0, 2),
                                      )
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      // Spectator header with close button
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade100,
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(7.0),
                                            topRight: Radius.circular(7.0),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(Icons.visibility, color: Colors.blue, size: 22),
                                                const SizedBox(width: 8),
                                                Text(
                                                  "Spectating Game #$spectatedGameId",
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.blue,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            ElevatedButton.icon(
                                              icon: const Icon(Icons.close, size: 18),
                                              label: const Text("Stop"),
                                              onPressed: () {
                                                // *** STOP SPECTATING LOGIC ***
                                                print('⏹️ Stopping spectator mode for game $spectatedGameId');
                                                isSpectating = false;
                                                spectatedGameId = -1;
                                                gameData = {}; // Clear the spectator data
                                                // Optionally send a message to server? (Not strictly necessary if server handles disconnects)
                                                // final serviceProvider = ServiceProvider.of(context);
                                                // serviceProvider.socketService.sendToServer({'action': 'stopSpectating', 'gameId': spectatedGameId});
                                                context.read<SetStateCubit>().setState(); // Update UI
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red,
                                                foregroundColor: Colors.white,
                                                minimumSize: const Size(80, 30),
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Spectator game board
                                      Expanded(
                                        child: SpectatorGameBoard(gameData: gameData), // Pass app.gameData
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ] : []) +
                            // Unity Settings
                            gameDices.widgetUnitySettings(state)),
                  ),
                ),

                // General Settings Tab
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.blue.shade50,
                        Colors.white,
                      ],
                    ),
                  ),
                  child: Scrollbar(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ListView(
                        primary: true,
                        children: [
                          // Miscellaneous Settings Section
                          Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white,
                                    Colors.blue.shade50,
                                  ],
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(misc_, style: headingStyle),
                                    const Divider(thickness: 1.5),
                                    const SizedBox(height: 8),
                                    // Animation Checkbox
                                    Theme(
                                      data: Theme.of(context).copyWith(
                                        checkboxTheme: CheckboxThemeData(
                                          fillColor: MaterialStateProperty.resolveWith<Color>(
                                            (Set<MaterialState> states) {
                                              if (states.contains(MaterialState.selected)) {
                                                return accentColor;
                                              }
                                              return Colors.grey.shade400;
                                            },
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ),
                                      ),
                                      child: inputItems.widgetCheckbox(
                                        (x) => {boardAnimation = x, state()},
                                        boardAnimation_,
                                        boardAnimation,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    // Language Selection
                                    Text("Language", style: subtitleStyle),
                                    const SizedBox(height: 8),
                                    inputItems.widgetDropDownList(
                                      () => {},
                                      " $choseLanguage_",
                                      differentLanguages,
                                      (language) => {
                                        chosenLanguage = language,
                                        context.read<LanguageBloc>().add(
                                          LanguageChanged(language: language),
                                        ),
                                        context.read<SetStateCubit>().setState()
                                      },
                                      chosenLanguage,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )));
  }
}
