import 'dart:convert';

import 'unity_message.dart';
import 'package:flutter_unity_widget/flutter_unity_widget.dart';

import 'dices.dart';

extension UnityCommunication on Dices {
  sendResetToUnity() {
    UnityMessage msg = UnityMessage.reset(nrDices, nrTotalRolls);

    var json = msg.toJson();

    unityWidgetController.postMessage(
      "GameManager",
      "flutterMessage",
      jsonEncode(json),
    );
  }

  sendStartToUnity() {
    UnityMessage msg = UnityMessage.start();

    var json = msg.toJson();

    unityWidgetController.postMessage(
      "GameManager",
      "flutterMessage",
      jsonEncode(json),
    );
  }

  sendDicesToUnity() {
    var msg = UnityMessage.updateDices(diceValue);

    var json = msg.toJson();

    unityWidgetController.postMessage(
      "GameManager",
      "flutterMessage",
      jsonEncode(json),
    );
  }

  sendColorsToUnity() {
    var msg = UnityMessage.updateColors(unityColors);

    var json = msg.toJson();

    unityWidgetController.postMessage(
      "GameManager",
      "flutterMessage",
      jsonEncode(json),
    );
  }

  sendTransparencyChangedToUnity() {
    var msg = UnityMessage.changeBool("Transparency", unityTransparent);

    var json = msg.toJson();

    unityWidgetController.postMessage(
      "GameManager",
      "flutterMessage",
      jsonEncode(json),
    );
  }

  sendLightMotionChangedToUnity() {
    var msg = UnityMessage.changeBool("LightMotion", unityLightMotion);

    var json = msg.toJson();

    unityWidgetController.postMessage(
      "GameManager",
      "flutterMessage",
      jsonEncode(json),
    );
  }

  sendFunChangedToUnity() {
    var msg = UnityMessage.changeBool("Fun", unityFun);

    var json = msg.toJson();

    unityWidgetController.postMessage(
      "GameManager",
      "flutterMessage",
      jsonEncode(json),
    );
  }

  sendSnowEffectChangedToUnity() {
    var msg = UnityMessage.changeBool("SnowEffect", unitySnowEffect);

    var json = msg.toJson();

    unityWidgetController.postMessage(
      "GameManager",
      "flutterMessage",
      jsonEncode(json),
    );
  }

  // Communication from Unity to Flutter
  onUnityMessage(message) {
    var msg = message.toString();
    print("Received message from unity: $msg");
    try {
      var json = jsonDecode(msg);
      if (json["actionUnity"] == "results") {
        diceValue = json["diceResult"].cast<int>();
        callbackUpdateDiceValues();
        nrRolls += 1;
      }
      if (json["actionUnity"] == "unityIdentifier") {
        unityId = json["unityId"];
        sendSnowEffectChangedToUnity();
        sendFunChangedToUnity();
        sendLightMotionChangedToUnity();
        sendResetToUnity();
        if (callbackCheckPlayerToMove()) {
          sendStartToUnity();
        }
      }
    } catch (e) {
      //Error
    }
  }

  onUnityUnloaded() {}

  // Callback that connects the created controller to the unity controller
  onUnityCreated(controller) {
    unityWidgetController = controller;
    unityCreated = true;
    sendResetToUnity();
    callbackUnityCreated();

    print("Unity Created");
  }

  // Communication from Unity when new scene is loaded to Flutter
  onUnitySceneLoaded(SceneLoaded? sceneInfo) {}
}
