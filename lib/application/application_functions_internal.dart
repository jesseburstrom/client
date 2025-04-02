// lib/application/application_functions_internal.dart
import 'package:flutter/material.dart';
import 'package:yatzy/dices/unity_communication.dart';
import '../startup.dart';
import 'application.dart';
import '../utils/yatzy_mapping_client.dart'; // <-- Import client-side mapping
import '../states/cubit/state/state_cubit.dart'; // Import SetStateCubit
import 'package:provider/provider.dart'; // Import Provider


extension ApplicationFunctionsInternal on Application {
  // ... (clearFocus remains the same) ...
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
      String? selectionLabel = getSelectionLabel(gameType, cell); // Use mapping function
      if (selectionLabel == null) {
          print("Error: Could not find label for cell index $cell");
          return; // Don't proceed if label is invalid
      }

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
        // Handle offline mode - just continue with local updates
      }

      // --- Local Update (Optimistic UI) ---
      // Apply the selection locally immediately for responsiveness.
      // Server confirmation will solidify the state via onGameUpdate.
      applyLocalSelection(player, cell, cellValue[player][cell]);
      // ---------------------------------

    } else {
        print("Ignoring cell click: Not my turn or cell invalid/fixed.");
    }
  }

  // New function to apply local UI changes after selection
  void applyLocalSelection(int player, int cell, int score) {
     if (gameDices.unityDices) {
       gameDices.sendResetToUnity();
       // Don't send start - wait for server to confirm next turn
     }

     appColors[player + 1][cell] = Colors.green.withAlpha(178); // Use alpha consistent with colorBoard
     fixedCell[player][cell] = true;
     cellValue[player][cell] = score; // Ensure value is set if passed

     // Update Sums locally
     var sum = 0;
     var totalSum = 0;
     var upperHalfSet = 0;
     for (var i = 0; i < 6; i++) {
       if (fixedCell[player][i]) {
         upperHalfSet++;
         sum += cellValue[player][i] as int; // Cast to int
       }
     }
     totalSum = sum;
     appText[player + 1][6] = sum.toString(); // Sum cell index = 6
     cellValue[player][6] = sum; // Store sum value

     // Bonus calculation index = 7
     int bonusIndex = 7;
     int bonusValue = 0; // Store calculated bonus value
     if (sum >= bonusSum) {
       bonusValue = bonusAmount;
       appText[player + 1][bonusIndex] = bonusAmount.toString();
       totalSum += bonusAmount;
     } else {
       // Check if all upper section cells are fixed
       final allUpperFixed = !fixedCell[player].sublist(0, 6).contains(false);
       if (allUpperFixed) {
         bonusValue = 0; // All fixed, no bonus
         appText[player + 1][bonusIndex] = "0";
       } else {
         bonusValue = sum - bonusSum; // Deficit
         appText[player + 1][bonusIndex] = (sum - bonusSum).toString();
       }
     }
     cellValue[player][bonusIndex] = bonusValue; // Store bonus/deficit


      // Lower section sum calculation
     for (var i = 8; i < totalFields -1; i++) { // Skip Sum, Bonus, Total (indices 6, 7, totalFields-1)
       if (fixedCell[player][i]) {
         totalSum += cellValue[player][i] as int;
       }
     }
      // Update Total Sum cell (index = totalFields - 1)
      int totalSumIndex = totalFields - 1;
      appText[player + 1][totalSumIndex] = totalSum.toString();
      cellValue[player][totalSumIndex] = totalSum;


     // Zero results for remaining selectable cells for this player?
     // This might be premature, let the server state dictate.
     // Clear focus remains useful.
     clearFocus();

     // Check if this player finished locally (for UI feedback, maybe)
      // Check all cells except Sum, Bonus, Total
      bool playerFinished = true;
      for(int j=0; j<totalFields; j++) {
          if (j != 6 && j != 7 && j != totalFields - 1 && !fixedCell[player][j]) {
              playerFinished = false;
              break;
          }
      }
      if (playerFinished) {
          print("Player $player finished locally.");
          // Server will confirm overall game finish status.
      }

     // Don't advance turn locally - wait for server message `onGameUpdate`
     colorBoard(); // Update colors immediately for selection feedback
     gameDices.clearDices(); // Clear dice display

     // ***** FIX: Trigger board animation if enabled *****
     if (boardAnimation) { // Check the flag from settings
       print('🎬 Triggering board animation');
       try {
         // Animate the row that was just selected
         animation.animateBoard(); // Pass player index + 1 (for the player row)
         // Optionally animate the header row too?
         // animation.animateBoardRow(0);
       } catch (e) {
         print("Error starting animation: $e");
       }
     }
     // ***** END FIX *****
     // Trigger UI update
     try {
       context.read<SetStateCubit>().setState();
     } catch (e) {
       print('⚠️ Error updating UI state: $e');
       // Continue without updating state
     }
  }


  // calcNewSums is now mostly handled by applyLocalSelection and server updates
  // Keep the coloring part if needed separately
  // calcNewSums(int player, int cell) { ... } // <-- REMOVE OR REFACTOR

  colorBoard() {
    // Update player column colors based on playerToMove and playerActive status
    for (var i = 0; i < nrPlayers; i++) {
      Color columnColor;
      if (i == playerToMove) {
        columnColor = Colors.greenAccent.withAlpha(77); // ~0.3 alpha
      } else if (playerActive != null && i < playerActive.length && playerActive[i]) {
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
