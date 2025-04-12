import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yatzy/application/application_functions_internal.dart';
import 'package:yatzy/dices/unity_communication.dart';
import 'package:yatzy/services/socket_service.dart';
import '../dices/dices.dart';
import '../input_items/input_items.dart';
import '../startup.dart';
import '../states/cubit/state/state_cubit.dart';
import 'languages_application.dart';

class Application with LanguagesApplication  {
  final BuildContext context;
  final InputItems inputItems;
  Application({required this.context, required this.gameDices, required this.inputItems}) {
    gameDices.setCallbacks(callbackUpdateDiceValues, callbackUnityCreated,
        callbackCheckPlayerToMove);
    languagesSetup(getChosenLanguage(), getStandardLanguage());
  }

  Function getChosenLanguage() {
    String f() {
      return chosenLanguage;
    }
    return f;
  }

  String getStandardLanguage() {
    return standardLanguage;
  }

  var userName = "Yatzy";
  var chosenLanguage = "Swedish";

  bool isSpectating = false;
  int spectatedGameId = -1;
  // Settings properties
  dynamic tabController;
  var textEditingController = TextEditingController();
  var focusNode = FocusNode();
  //var animation = AnimationsApplication();
  var games = [];
  var presentations = [];

  // Application properties

  var stackedWidgets = <Widget>[];

  // "Ordinary" ,"Maxi"
  var gameType = "Ordinary";
  var nrPlayers = 1;

  // Used by animation
  var maxNrPlayers = 4;
  var maxTotalFields = 23;

  // Socket game
  Map<String, dynamic> gameData = {};

  var gameId = -1;
  //var playerIds = [];
  List<bool> playerActive = [];

  var totalFields = 18;
  var bonusSum = 63;
  var bonusAmount = 50;
  var myPlayerId = -1;
  var playerToMove = 0;
  var winnerId = -1;
  var gameStarted = false;
  var gameFinished = false;

  var boardXPos = [],
      boardYPos = [],
      boardWidth = [],
      boardHeight = [],
      cellValue = [],
      fixedCell = [],
      appText = [],
      appColors = [],
      focusStatus = [];

  late Dices gameDices;
  var serverId = "";

  bool isSettingUpGame = false; // <-- Add this flag

  // Reference to the modern socket service
  SocketService? socketService;

  void updateBoardColors() {
    // Safety checks: Ensure arrays are initialized and have expected dimensions
    if (appColors.isEmpty || appColors.length <= nrPlayers ||
        fixedCell.isEmpty || fixedCell.length < nrPlayers ||
        playerActive.isEmpty || playerActive.length < nrPlayers) {
      print("⚠️ Cannot update board colors: State arrays not ready or incorrect size.");
      // Optionally call setup() if state seems completely uninitialized? Be careful with loops.
      // setup(); // Use with caution
      return;
    }

    // Update player column colors based on playerToMove and playerActive status
    for (var i = 0; i < nrPlayers; i++) {
      // Ensure inner lists exist and have correct length before accessing
      if (i + 1 >= appColors.length || appColors[i + 1] == null || appColors[i + 1].length != totalFields) {
        print("⚠️ Initializing appColors sublist for player $i");
        // Initialize or resize if necessary. Ensure appColors[0] (header) is preserved.
        while (appColors.length <= i + 1) {
          appColors.add(List.filled(totalFields, Colors.transparent)); // Add missing lists
        }
        if (appColors[i + 1].length != totalFields) {
          appColors[i + 1] = List.filled(totalFields, Colors.transparent); // Resize existing
        }
      }
      if (i >= fixedCell.length || fixedCell[i] == null || fixedCell[i].length != totalFields) {
        print("⚠️ fixedCell array issue for player $i - Cannot update colors reliably.");
        continue; // Skip this player if fixedCell state is inconsistent
      }

      Color columnColor;
      bool isCurrentPlayer = (i == playerToMove);
      // Use safe bounds check for playerActive
      bool isActivePlayer = (i < playerActive.length && playerActive[i]);

      // Determine base color for the column
      if (isCurrentPlayer && isActivePlayer) {
        // Current player's turn & they are active
        columnColor = Colors.greenAccent.withAlpha(100); // Brighter highlight
      } else if (isActivePlayer) {
        // Not current player's turn, but they are active
        columnColor = Colors.grey.withAlpha(77);
      } else {
        // Player is inactive (disconnected/aborted)
        columnColor = Colors.black.withAlpha(90); // Darker/distinct inactive color
      }

      // Apply colors cell by cell
      for (var j = 0; j < totalFields; j++) {
        bool isFixed = fixedCell[i][j];
        // Check for non-score cells (Sum, Bonus, Total) - these have special colors
        bool isNonScoreCell = (j == 6 || j == 7 || j == totalFields - 1); // Adjust indices based on your gameType logic if needed

        if (isNonScoreCell) {
          // Always use the special blueish color for calculated fields
          appColors[i + 1][j] = Colors.blue.withAlpha(77);
        } else if (isFixed) {
          // Use a distinct color for cells that are *already* fixed by the player
          // Keep the color consistent regardless of whose turn it is.
          appColors[i + 1][j] = Colors.lightGreen.withAlpha(150); // A slightly different green maybe?
        } else {
          // Apply the base column color (current turn, active, inactive)
          // This covers cells available for the current player or showing state for others.
          appColors[i + 1][j] = columnColor;
        }
      }
    }

    // Update header colors (Optional: Highlight based on current player's available moves)
    // Ensure header row exists and has correct length
    if (appColors.isNotEmpty && appColors[0] != null && appColors[0].length == totalFields &&
        playerToMove >= 0 && playerToMove < nrPlayers && fixedCell.isNotEmpty && fixedCell[playerToMove] != null && fixedCell[playerToMove].length == totalFields) {
      for (var j = 0; j < totalFields; j++) {
        bool isNonScore = (j == 6 || j == 7 || j == totalFields - 1);
        bool isFixedByCurrentPlayer = fixedCell[playerToMove][j];

        if (isNonScore) {
          appColors[0][j] = Colors.blueAccent.withAlpha(204); // Header color for calculated fields
        } else if (isFixedByCurrentPlayer) {
          appColors[0][j] = Colors.white.withAlpha(100); // Dimmer header for fixed items for the current player
        } else {
          appColors[0][j] = Colors.white.withAlpha(200); // Brighter header for available items
        }
      }
    }
    print("🎨 Board colors updated. Current player: $playerToMove");
  }

  void resetForNewGame() {
    print('🔄 Resetting application state for new game...');
    gameId = -1;
    gameStarted = false;
    gameFinished = false;
    myPlayerId = -1;
    playerToMove = 0; // Reset to default starting player index (usually 0)
    winnerId = -1;
    gameData = {}; // Clear old game data map

    // Clear player lists from previous game (ensure they are dynamic or recreate)
    // Assuming userNames and playerActive are Lists, clearing them.
    // If they have fixed size based on maxNrPlayers, re-initialize instead.
    userNames = []; // Or List<String>.filled(maxNrPlayers, "") if size is fixed
    playerActive = []; // Or List<bool>.filled(maxNrPlayers, false) if size is fixed
    // playerIds should also be cleared if used directly elsewhere

    // Reset dice state

    gameDices.clearDices(); // Ensure Dices class has this method
    // If using Unity, maybe send a reset message?
    // if (this.gameDices.unityDices && this.gameDices.unityCreated) {
    //   this.gameDices.sendResetToUnity();
    // }

    // Reset chat (optional, depends on desired behavior)
    // Option 1: Clear all messages
    chat.messages.clear();
    // Option 2: Reset to initial empty placeholders if that's the design
    // chat.messages = List<ChatMessage>.generate(15, (index) => ChatMessage("", "Sender"));

    // Reset visual board state arrays (important!)
    // Ensure these lists are cleared or re-initialized
    boardXPos = [];
    boardYPos = [];
    boardWidth = [];
    boardHeight = [];
    cellValue = [];
    fixedCell = [];
    appColors = [];
    focusStatus = [];
    // Reset animation state if necessary
    // animation = AnimationsApplication(); // Or reset specific animation properties

    // Reset spectator state
    isSpectating = false;
    spectatedGameId = -1;

    print('🔄 Application state reset complete.');
  }

  bool callbackCheckPlayerToMove() {
    return playerToMove == myPlayerId;
  }

  callbackUnityCreated() {
    if (myPlayerId == playerToMove) {
      gameDices.sendStartToUnity();
    }
  }

  callbackUpdateDiceValues() {
    Map<String, dynamic> msg = {};
    msg["action"] = "sendDices";
    msg["gameId"] = gameId;
    //msg["playerIds"] = playerIds;
    msg["diceValue"] = gameDices.diceValue;
    
    // Use socketService for sending dice values to ensure delivery
    // This ensures we use the modern socket system which is correctly connected
    print('🎲 Sending dice values to other players: ${gameDices.diceValue}');
    if (socketService != null && socketService!.isConnected) {
      socketService?.sendToClients(msg);
    }
  }

  setAppText() {
   if (gameType.startsWith("Maxi")) {
      appText[0] = [
        ones_,
        twos_,
        threes_,
        fours_,
        fives_,
        sixes_,
        sum_,
        "$bonus_ ( $bonusAmount )",
        pair_,
        twoPairs_,
        threePairs_,
        threeOfKind_,
        fourOfKind_,
        fiveOfKind_,
        smallStraight_,
        largeStraight_,
        fullStraight_,
        house32_,
        house33_,
        house24_,
        chance_,
        maxiYatzy_,
        totalSum_
      ];
    } else {
      appText[0] = [
        ones_,
        twos_,
        threes_,
        fours_,
        fives_,
        sixes_,
        sum_,
        "$bonus_ ( $bonusAmount )",
        pair_,
        twoPairs_,
        threeOfKind_,
        fourOfKind_,
        house_,
        smallStraight_,
        largeStraight_,
        chance_,
        yatzy_,
        totalSum_
      ];
    }
  }

  setup() {
    topScore.loadTopScoreFromServer(gameType, context.read<SetStateCubit>());
    //gameStarted = true;
    playerToMove = 0;
    winnerId = -1;

    if (gameType.startsWith("Maxi")) {
      totalFields = 23;
      gameDices.initDices(6);
      bonusSum = 84;
      bonusAmount = 100;

    } else {
      totalFields = 18;
      gameDices.initDices(5);
      bonusSum = 63;
      bonusAmount = 50;

    }

    appText = [];
    if (isTesting) {
      for (var i = 0; i < nrPlayers + 1; i++) {
        var textColumn = List.filled(6, "0") +
            List.filled(1, "0") +
            List.filled(1, (-bonusSum).toString()) +
            List.filled(totalFields - 9, "0") +
            List.filled(1, "0");
        textColumn[5] = "";
        textColumn[totalFields - 2] = "";
        appText.add(textColumn);
      }
    } else {
      for (var i = 0; i < nrPlayers + 1; i++) {
        appText.add(List.filled(6, "") +
            List.filled(1, "0") +
            List.filled(1, (-bonusSum).toString()) +
            List.filled(totalFields - 9, "") +
            List.filled(1, "0"));
      }
    }
    setAppText();

    boardXPos = [List.filled(maxTotalFields, 0.0)];
    boardYPos = [List.filled(maxTotalFields, 0.0)];
    boardWidth = [List.filled(maxTotalFields, 0.0)];
    boardHeight = [List.filled(maxTotalFields, 0.0)];
    for (var i = 0; i < maxNrPlayers; i++) {
      boardXPos.add(List.filled(maxTotalFields, 0.0));
      boardYPos.add(List.filled(maxTotalFields, 0.0));
      boardWidth.add(List.filled(maxTotalFields, 0.0));
      boardHeight.add(List.filled(maxTotalFields, 0.0));
    }
    clearFocus();
    fixedCell = [];
    cellValue = [];
    appColors = [
      List.filled(6, Colors.white.withValues(alpha: 0.3)) +
          List.filled(2, Colors.blueAccent.withValues(alpha: 0.8)) +
          List.filled(totalFields - 9, Colors.white.withValues(alpha: 0.3)) +
          List.filled(1, Colors.blueAccent.withValues(alpha: 0.8))
    ];

    for (var i = 0; i < nrPlayers; i++) {
      if (isTesting) {
        var holdColumn = List.filled(totalFields, true);
        holdColumn[5] = false;
        holdColumn[totalFields - 2] = false;
        fixedCell.add(holdColumn);
      } else {
        fixedCell.add(List.filled(6, false) +
            [true, true] +
            List.filled(totalFields - 9, false) +
            [true]);
      }

      if (i == playerToMove) {
        appColors.add(List.filled(6, Colors.greenAccent.withValues(alpha: 0.3)) +
            List.filled(2, Colors.blue.withValues(alpha: 0.3)) +
            List.filled(totalFields - 9, Colors.greenAccent.withValues(alpha: 0.3)) +
            List.filled(1, Colors.blue.withValues(alpha: 0.3)));
      } else {
        appColors.add(List.filled(6, Colors.grey.withValues(alpha: 0.3)) +
            List.filled(2, Colors.blue.withValues(alpha: 0.3)) +
            List.filled(totalFields - 9, Colors.grey.withValues(alpha: 0.3)) +
            List.filled(1, Colors.blue.withValues(alpha: 0.3)));
      }

      if (isTesting) {
        var valueColumn = List.filled(totalFields, 0);
        valueColumn[5] = -1;
        valueColumn[totalFields - 2] = -1;
        cellValue.add(valueColumn);
      } else {
        cellValue.add(List.filled(totalFields, -1));
      }
    }
    if (gameDices.unityCreated) {
      gameDices.sendResetToUnity();
      if (myPlayerId == playerToMove) {
        gameDices.sendStartToUnity();
      }
    }
  }

  // Method to set the socket service reference
  void setSocketService(SocketService service) {
    print('🔌 Application: Setting socket service reference');
    socketService = service;
  }
}
