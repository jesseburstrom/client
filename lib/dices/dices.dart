import 'dart:math';

import 'package:flutter/cupertino.dart';
import '../input_items/input_items.dart';
import '../startup.dart';
import 'unity_communication.dart';
import 'package:flutter_unity_widget/flutter_unity_widget.dart';

import 'languages_dices.dart';


class Dices extends LanguagesDices  {
  final Function setState;
  final InputItems inputItems;
  Dices(
      {required Function getChosenLanguage, required String standardLanguage, required this.setState, required this.inputItems}) {
    languagesSetup(getChosenLanguage, standardLanguage);
  }

  setCallbacks(cbUpdateDiceValues, cbUnityCreated, cbCheckPlayerToMove) {
    callbackUpdateDiceValues = cbUpdateDiceValues;
    callbackUnityCreated = cbUnityCreated;
    callbackCheckPlayerToMove = cbCheckPlayerToMove;
  }

  var holdDices = [], holdDiceText = [], holdDiceOpacity = [];


  var nrRolls = 0;
  var nrTotalRolls = 3;
  var nrDices = 5;
  var diceValue = List.filled(5, 0);
  var diceRef = [
    "assets/images/empty.jpg",
    "assets/images/empty.jpg",
    "assets/images/empty.jpg",
    "assets/images/empty.jpg",
    "assets/images/empty.jpg"
  ];
  var diceFile = [
    "empty.jpg",
    "1.jpg",
    "2.jpg",
    "3.jpg",
    "4.jpg",
    "5.jpg",
    "6.jpg"
  ];
  late Function callbackUpdateDiceValues;
  late Function callbackUnityCreated;
  late Function callbackCheckPlayerToMove;
  late Animation<double> sizeAnimation;
  late UnityWidgetController unityWidgetController;
  var unityCreated = false;
  var unityColors = [0.0, 0.0, 0.0, 0.1];
  var unityDices = false;
  var unityTransparent = true;
  var unityLightMotion = false;
  var unityFun = false;
  var unitySnowEffect = false;
  var unityId = "";


  clearDices() {
    diceValue = List.filled(nrDices, 0);
    holdDices = List.filled(nrDices, false);
    holdDiceText = List.filled(nrDices, "");
    holdDiceOpacity = List.filled(nrDices, 0.0);
    diceRef = List.filled(nrDices, "assets/images/empty.jpg");
    nrRolls = 0;
  }

  initDices(int nrdices) {
    if (unityCreated) {
      sendResetToUnity();
    }
    nrDices = nrdices;
    diceValue = List.filled(nrDices, 0);
    holdDices = List.filled(nrDices, false);
    holdDiceText = List.filled(nrDices, "");
    holdDiceOpacity = List.filled(nrDices, 0.0);
    diceRef = List.filled(nrDices, "assets/images/empty.jpg");
    nrRolls = 0;
  }

  holdDice(int dice) {
    if (diceValue[0] != 0 && nrRolls < nrTotalRolls) {
      holdDices[dice] = !holdDices[dice];
      if (holdDices[dice]) {
        holdDiceText[dice] = hold_;
        holdDiceOpacity[dice] = 0.7;
      } else {
        holdDiceText[dice] = "";
        holdDiceOpacity[dice] = 0.0;
      }
    }
  }

  updateDiceImages() {
    for (var i = 0; i < nrDices; i++) {
      diceRef[i] = "assets/images/${diceFile[diceValue[i]]}";
    }
  }

  bool rollDices(BuildContext context) {
    // ***** FIX: Add checks for game state *****
    if (app.gameFinished) { // Check if the game is globally finished
      print("🎲 Roll blocked: Game is finished.");
      return false;
    }

    if (!callbackCheckPlayerToMove()) { // Check if it's actually my turn
      print("🎲 Roll blocked: Not my turn.");
      return false;
    }
    // ***** END FIX *****
    if (nrRolls < nrTotalRolls) {
      nrRolls += 1;
      var randomNumberGenerator = Random(DateTime.now().millisecondsSinceEpoch);
      for (var i = 0; i < nrDices; i++) {
        if (!holdDices[i]) {
          diceValue[i] = randomNumberGenerator.nextInt(6) + 1;
          diceRef[i] = "assets/images/${diceFile[diceValue[i]]}";
        } else {
          if (nrRolls == nrTotalRolls) {
            holdDices[i] = false;
            holdDiceText[i] = "";
            holdDiceOpacity[i] = 0.0;
          }
        }
      }
      callbackUpdateDiceValues();

      return true;
    }
    print("🎲 Roll blocked: No rolls left ($nrRolls/$nrTotalRolls).");
    return false;
  }

  List<Widget> widgetUnitySettings(Function state) {
    List<Widget> widgets = [];
    if (!showUnityOptions) {
      return widgets;
    }
    widgets.add(inputItems.widgetCheckbox(
            (x) => {unityDices = x, state()}, choseUnity_, unityDices));
    widgets.add(inputItems.widgetCheckbox(
            (x) => {unityLightMotion = x, state() , sendLightMotionChangedToUnity()},
        lightMotion_,
        unityLightMotion));
    widgets.add(inputItems.widgetCheckbox(
            (x) => {unityFun = x, state(), sendFunChangedToUnity()}, fun_, unityFun));
    widgets.add(inputItems.widgetCheckbox(
            (x) => {unitySnowEffect = x, state(),sendSnowEffectChangedToUnity()},
        snowEffect_,
        unitySnowEffect));
    return widgets;
  }
}
