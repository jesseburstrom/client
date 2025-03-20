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

        var gameText = gameTypeText +
            " " +
            games[i]["connected"].toString() +
            "/" +
            games[i]["nrPlayers"].toString() +
            " " +
            games[i]["userNames"].toString();

        if (games[i]["playerIds"].indexOf(net.socketConnectionId) == -1) {
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
      } else {
        ongoingGames++;
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

  onAttemptJoinGame(BuildContext context, int i) {
    Map<String, dynamic> msg = {};

    msg = games[i];

    msg["userName"] = userName;
    msg["action"] = "requestJoinGame";

    // Send the join game request
    print('🎮 Joining multiplayer game: ${msg["gameType"]} (${msg["nrPlayers"]} players)');

    // Get the service provider
    final serviceProvider = ServiceProvider.of(context);
    final socketServiceConnected = serviceProvider.socketService.isConnected;

    // Always use the modern SocketService if it's connected
    if (socketServiceConnected) {
      print('🎮 Using modern SocketService for joining game');
      serviceProvider.socketService.sendToServer(msg);
    }
  }

  onStartGameButton(BuildContext context, Function state) async {
    final serviceProvider = ServiceProvider.of(context);
    final socketServiceConnected = serviceProvider.socketService.isConnected;
    final legacyNetConnected = net.socketConnectionId != "";

    print('🎮 onStartGameButton: Socket connections - Modern: $socketServiceConnected, Legacy: $legacyNetConnected');

    // Either the modern or legacy socket should have a connection
    if (socketServiceConnected || legacyNetConnected) {
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
  }

  onChangeUserName(value) {
    userName = textEditingController.text;
  }

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
      color: Theme.of(context).colorScheme.onBackground,
    );

    final subtitleStyle = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w500,
      color: Theme.of(context).colorScheme.onBackground,
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
                              // Game Type Selection
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
                                          Text("Game Type", style: headingStyle),
                                          const SizedBox(height: 8),
                                          inputItems.widgetStringRadioButtonSplit(
                                              state,
                                              [
                                                "Mini",
                                                "Ordinary",
                                                "Maxi",
                                                "MaxiR3",
                                                "MaxiE3",
                                                "MaxiRE3"
                                              ],
                                              [
                                                gameTypeMini_,
                                                gameTypeOrdinary_,
                                                gameTypeMaxi_,
                                                gameTypeMaxiR3_,
                                                gameTypeMaxiE3_,
                                                gameTypeMaxiRE3_
                                              ],
                                              (x) => {gameType = x},
                                              gameType,
                                              3),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),

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
