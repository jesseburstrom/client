// lib/application/application_functions_internal.dart
import 'package:flutter/material.dart';
import 'application.dart';
import '../utils/yatzy_mapping_client.dart';



extension ApplicationFunctionsInternal on Application {
  clearFocus() {
    focusStatus = [];
    for (var i = 0; i < nrPlayers; i++) {
      focusStatus.add(List.filled(totalFields, 0));
    }
  }


  cellClick(int player, int cell) {
    // Replace isMyTurn with the original logic
    if (player == playerToMove &&
        myPlayerId == playerToMove &&
        !fixedCell[player][cell] &&
        cellValue[player][cell] != -1) {

      // Get the string label for the selected cell
      String? selectionLabel = getSelectionLabel(gameType, cell);

      Map<String, dynamic> msg = {};
      msg["diceValue"] = gameDices.diceValue; // Current dice
      msg["gameId"] = gameId;
      // msg["playerIds"] = playerIds; // Server knows players in gameId
      msg["player"] = player; // Send player index (server validates)
      // msg["cell"] = cell; // <-- REMOVE Index
      msg["selectionLabel"] = selectionLabel; // <-- SEND Label String
      msg["score"] = cellValue[player][cell]; // Send the score client calculated
      msg["action"] = "sendSelection"; // Use consistent action name

      // Use the stored socketService directly instead of trying to access through ServiceProvider
      if (socketService != null && socketService!.isConnected) {
        print('🎮 Sending selection via socketService: player $player cell $cell label "$selectionLabel" score ${msg["score"]}');
        socketService!.sendToClients(msg);
      } else {
        print('❌ Cannot send selection: socketService is null or not connected');
      }
      print("sendSelection");
      clearFocus();
      gameDices.clearDices();

    } else {
        print("Ignoring cell click: Not my turn or cell invalid/fixed.");
    }
  }

  colorBoard() {
    // Update player column colors based on playerToMove and playerActive status
    for (var i = 0; i < nrPlayers; i++) {
      Color columnColor;
      if (i == playerToMove) {
        columnColor = Colors.greenAccent.withAlpha(77); // ~0.3 alpha
      } else if (i < playerActive.length && playerActive[i]) {
        columnColor = Colors.grey.withAlpha(77); // ~0.3 alpha
      } else {
        // disconnected/aborted player
        columnColor = Colors.black.withAlpha(77); // ~0.3 alpha
      }

      for (var j = 0; j < totalFields; j++) {
          // Keep special colors for non-selectable cells
          if (j == 6 || j == 7 || j == totalFields - 1) { // Sum, Bonus, Total
              appColors[i + 1][j] = Colors.blue.withAlpha(77); // Special color for calculated fields
          }
          // Apply base color only if not already fixed with the selection color
          else if (!(fixedCell[i][j] && appColors[i + 1][j] == Colors.green.withAlpha(178))) { // Check if it's the 'just selected' color
             appColors[i + 1][j] = columnColor;
          }
          // Re-apply selection color if cell is fixed
          else if (fixedCell[i][j]) {
              appColors[i + 1][j] = Colors.green.withAlpha(178); // ~0.7 alpha for selected/fixed
          }
      }
    }
      // Update header colors based on which cells are fixed for the *current* player
     if (playerToMove >= 0 && playerToMove < nrPlayers) {
         for (var j = 0; j < totalFields; j++) {
              // Keep special colors
              if (j == 6 || j == 7 || j == totalFields - 1) {
                  appColors[0][j] = Colors.blueAccent.withAlpha(204); // ~0.8 alpha
              }
              // Highlight fixed cells in header? Or just dim unfixed? Let's dim unfixed.
              else if (fixedCell[playerToMove][j]) {
                   appColors[0][j] = Colors.white.withAlpha(178); // Brighter/Solid for fixed
              } else {
                   appColors[0][j] = Colors.white.withAlpha(77); // Dimmer for available
              }
         }
     }

  }

}
