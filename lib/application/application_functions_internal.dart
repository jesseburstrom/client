import 'package:flutter/material.dart';
import 'package:yatzy/dices/unity_communication.dart';

import '../startup.dart';
import 'application.dart';

extension ApplicationFunctionsInternal on Application {
  clearFocus() {
    focusStatus = [];
    for (var i = 0; i < nrPlayers; i++) {
      focusStatus.add(List.filled(totalFields, 0));
    }
  }

  cellClick(int player, int cell) {
    if (player == playerToMove &&
        myPlayerId == playerToMove &&
        !fixedCell[player][cell] &&
        cellValue[player][cell] != -1) {
      Map<String, dynamic> msg = {};
      msg["diceValue"] = gameDices.diceValue;
      msg["gameId"] = gameId;
      msg["playerIds"] = playerIds;
      msg["player"] = player;
      msg["cell"] = cell;
      msg["action"] = "sendSelection";
      
      // Use the modern socket service if available
      if (socketService != null && socketService!.isConnected) {
        print('🎮 Sending selection via modern socket service: player $player cell $cell');
        socketService!.sendToClients(msg);
      }
      
      calcNewSums(player, cell);
    }
  }

  calcNewSums(int player, int cell) {
    if (gameDices.unityDices) {
      gameDices.sendResetToUnity();
      if (nrPlayers == 1) {
        gameDices.sendStartToUnity();
      }
    }

    appColors[playerToMove + 1][cell] = Colors.green.withValues(alpha: 0.7);
    fixedCell[playerToMove][cell] = true;
    // Update Sums
    var sum = 0;
    var totalSum = 0;
    var upperHalfSet = 0;
    for (var i = 0; i < 6; i++) {
      if (fixedCell[playerToMove][i]) {
        upperHalfSet++;
        sum += cellValue[playerToMove][i] as int;
      }
    }
    totalSum = sum;
    appText[playerToMove + 1][6] = sum.toString();
    if (sum >= bonusSum) {
      appText[playerToMove + 1][7] = bonusAmount.toString();
      totalSum += bonusAmount;
    } else {
      if (upperHalfSet != 6) {
        appText[playerToMove + 1][7] = (sum - bonusSum).toString();
      } else {
        appText[playerToMove + 1][7] = "0";
      }
    }
    for (var i = 8; i <= totalFields - 2; i++) {
      if (fixedCell[playerToMove][i]) {
        totalSum += cellValue[playerToMove][i] as int;
      }
    }
    appText[playerToMove + 1][totalFields - 1] = totalSum.toString();
    cellValue[playerToMove][totalFields - 1] = totalSum;

    // Zero results
    for (var i = 0; i < totalFields; i++) {
      if (!fixedCell[playerToMove][i]) {
        appText[playerToMove + 1][i] = "";
        cellValue[playerToMove][i] = -1;
      }
    }

    clearFocus();
    // Game finished for player
    if (!fixedCell[playerToMove].contains(false)) {

      topScore.updateTopScore(
          userName, cellValue[myPlayerId][totalFields - 1], gameType);

      // All players run this code so check if this is the right client, this freezes dice
      if (playerToMove == myPlayerId) {
        myPlayerId = -1;
      }
      // If game all finished send remove game to server
      // if (playerToMove == nrPlayers - 1) {
      //   Map<String, dynamic> msg = {};
      //
      //   msg = gameData;
      //   msg["action"] = "removeGame";
      //   net.sendToServer(msg);
      //   //context.read<NetBloc>().add(SendToServer(msg: msg));
      // }
    }
    // Get next active player (if some player aborted skip them)
    int previousPlayer = playerToMove;
    do {
      playerToMove = (playerToMove + 1) % nrPlayers;
    } while (!playerActive[playerToMove]);

    // Clear unfixed cells for the next player
    for (var i = 0; i < totalFields; i++) {
      if (!fixedCell[playerToMove][i]) {
        appText[playerToMove + 1][i] = "";
        cellValue[playerToMove][i] = -1;
      }
    }

    for (var i = 0; i < 6; i++) {
      if (fixedCell[playerToMove][i]) {
        appColors[0][i] = Colors.white.withValues(alpha: 0.7);
      } else {
        appColors[0][i] = Colors.white.withValues(alpha: 0.3);
      }
    }

    for (var i = 8; i < totalFields - 1; i++) {
      if (fixedCell[playerToMove][i]) {
        appColors[0][i] = Colors.white.withValues(alpha: 0.7);
      } else {
        appColors[0][i] = Colors.white.withValues(alpha: 0.3);
      }
    }

    colorBoard();
    gameDices.clearDices();
    if (boardAnimation) {
      animation.animateBoard();
    }
    
    // For multiplayer games, send a game update to all players about the turn change
    if (nrPlayers > 1) {
      print('🎮 Player turn changed: now it\'s player ${playerToMove}\'s turn');
      
      // Send a game update to notify all players about the turn change
      Map<String, dynamic> updateMsg = {};
      updateMsg["action"] = "onGameUpdate";
      updateMsg["gameId"] = gameId;
      updateMsg["gameType"] = gameType;
      updateMsg["nrPlayers"] = nrPlayers;
      updateMsg["connected"] = nrPlayers; // All players are connected
      updateMsg["playerIds"] = playerIds;
      updateMsg["userNames"] = userNames;
      updateMsg["gameStarted"] = true;
      updateMsg["playerToMove"] = playerToMove;
      updateMsg["diceValue"] = gameDices.diceValue;
      
      // Use the modern socket service if available for reliable delivery
      if (socketService != null && socketService!.isConnected) {
        print('🎮 Sending turn update via modern socket service');
        socketService!.sendToClients(updateMsg);
      }
    }
  }

  colorBoard() {
    for (var i = 0; i < nrPlayers; i++) {
      for (var j = 0; j < totalFields; j++) {
        if (!fixedCell[i][j]) {
          if (i == playerToMove) {
            appColors[i + 1][j] = Colors.greenAccent.withValues(alpha: 0.3);
          } else if (playerActive[i]) {
            appColors[i + 1][j] = Colors.grey.withValues(alpha: 0.3);
          } else {
            // disconnected player
            appColors[i + 1][j] = Colors.black.withValues(alpha: 0.3);
          }
        }
      }
    }
  }
}
