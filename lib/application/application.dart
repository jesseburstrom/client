import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yatzy/application/application_functions_internal.dart';
import 'package:yatzy/dices/unity_communication.dart';
import 'package:yatzy/services/socket_service.dart';
import '../dices/dices.dart';
import '../input_items/input_items.dart';
import '../startup.dart';
import '../states/cubit/state/state_cubit.dart';
import 'animations_application.dart';
import 'languages_application.dart';

// cannot have typedef inside class

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

  bool isSpectating = false;
  int spectatedGameId = -1;
  // Settings properties
  dynamic tabController;
  var textEditingController = TextEditingController();
  var focusNode = FocusNode();
  var animation = AnimationsApplication();
  var games = [];
  var presentations = [];
  var boardAnimation = false;

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
  var playerIds = [];
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

  var listenerKey = GlobalKey();
  late Dices gameDices;
  var serverId = "";

  var cellKeys = [];

  // Reference to the modern socket service
  SocketService? socketService;

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
    msg["playerIds"] = playerIds;
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
    gameStarted = true;
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
    animation.boardXAnimationPos = [List.filled(maxTotalFields, 0.0)];
    animation.boardYAnimationPos = [List.filled(maxTotalFields, 0.0)];
    for (var i = 0; i < maxNrPlayers; i++) {
      boardXPos.add(List.filled(maxTotalFields, 0.0));
      boardYPos.add(List.filled(maxTotalFields, 0.0));
      boardWidth.add(List.filled(maxTotalFields, 0.0));
      boardHeight.add(List.filled(maxTotalFields, 0.0));
      animation.boardXAnimationPos.add(List.filled(maxTotalFields, 0.0));
      animation.boardYAnimationPos.add(List.filled(maxTotalFields, 0.0));
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

    cellKeys = [];
    for (int i = 0; i < nrPlayers + 1; i++) {
      var tmp = [];
      for (int j = 0; j < totalFields; j++) {
        tmp.add(GlobalKey());
      }
      cellKeys.add(tmp);
    }
  }

  // Method to set the socket service reference
  void setSocketService(SocketService service) {
    print('🔌 Application: Setting socket service reference');
    socketService = service;
  }
}
