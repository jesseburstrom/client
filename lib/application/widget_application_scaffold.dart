import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yatzy/application/communication_application.dart';
import 'package:yatzy/chat/widget_chat.dart';
import 'package:yatzy/dices/unity_communication.dart';
import 'package:yatzy/dices/widget_dices.dart';
import 'package:yatzy/top_score/widget_top_scores.dart';

import '../router/router.gr.dart';
import '../scroll/widget_scroll.dart';
import '../services/service_provider.dart';
import '../startup.dart';
import '../states/cubit/state/state_cubit.dart';
import 'application.dart';
import 'widget_application.dart';

extension WidgetApplicationScaffold on Application {
  Widget widgetScaffold(BuildContext context, Function state) {
    screenWidth = MediaQuery.of(context).size.width;
    screenHeight = MediaQuery.of(context).size.height;
    devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    // Get best 16:9 fit
    var l = 0.0, t = 0.0, w = screenWidth, h = screenHeight, ratio = 16 / 9;
    if (w > h) {
      if (screenWidth / screenHeight < ratio) {
        h = screenWidth / ratio;
        t = (screenHeight - h) / 2;
      } else {
        w = screenHeight * ratio;
        l = (screenWidth - w) / 2;
      }
    } else {
      // topple screen, calculate best fit, topple back
      var l_ = 0.0, t_ = 0.0, w_ = screenHeight, h_ = screenWidth;

      if (screenHeight / screenWidth < ratio) {
        h_ = screenHeight / ratio;
        t_ = (screenWidth - h_) / 2;
      } else {
        w_ = screenWidth * ratio;
        l_ = (screenHeight - w_) / 2;
      }

      h = w_;
      w = h_;
      l = t_;
      t = l_;
    }

    //Widget empty(w,h) {return Container();}
    var floatingButtonSize = 0.06;

    Widget widgetFloatingButton(double size) {
      // Temporary move on portrait mode
      var moveButton = w > h ? 0 : h * 0.5;
      Widget buttonRegretGame = Container();
      if (regretGame) {
        buttonRegretGame = Positioned(
            //key: keySettings,
            left: l + (1.0 - floatingButtonSize * (size == h ? 2 : 1.1)) * w,
            top: t +
                (1.0 - floatingButtonSize * 3 * (size == w ? 2 : 1.1)) * h -
                moveButton,
            child: Stack(children: [
              Center(
                  child: SizedBox(
                      width: size * floatingButtonSize,
                      height: size * floatingButtonSize,
                      child: FittedBox(
                          fit: BoxFit.contain,
                          child: Text("$regretMovesLeft",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: regretMovesLeft > 0
                                    ? Colors.green[900]
                                    : Colors.red[900],
                              ))))),
              SizedBox(
                  width: size * floatingButtonSize,
                  height: size * floatingButtonSize,
                  child: FittedBox(
                    child: FloatingActionButton(
                        splashColor: Colors.transparent,
                        shape: const CircleBorder(),
                        heroTag: "RegretGame",
                        onPressed: () async {
                          if (playerToMove == myPlayerId &&
                              regretMovesLeft > 0) {
                            regretMovesLeft--;
                            resetDices();
                            if (gameDices.unityDices) {
                              gameDices.sendResetToUnity();
                              gameDices.sendStartToUnity();
                            }
                            Map<String, dynamic> msg = {};
                            msg["action"] = "sendDices";
                            msg["gameId"] = gameId;
                            msg["playerIds"] = playerIds;
                            msg["diceValue"] = gameDices.diceValue;
                            final serviceProvider = ServiceProvider.of(context);
                            serviceProvider.socketService.sendToClients(msg);
                            context.read<SetStateCubit>().setState();
                          }
                        },
                        backgroundColor: Colors.blue.withValues(alpha: 0.5),
                        child: FittedBox(
                            fit: BoxFit.contain,
                            child: Text(regretsLeft_,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: .5),
                                )))),
                  )),
            ]));
      }

      Widget buttonExtraMoves = Container();
      if (gameType == "MaxiE3" || gameType == "MaxiRE3") {
        buttonExtraMoves = Positioned(
            //key: keySettings,
            left: l + (1.0 - floatingButtonSize * (size == h ? 2 : 1.1)) * w,
            top: t +
                (1.0 -
                        floatingButtonSize *
                            (regretGame ? 4 : 3) *
                            (size == w ? 2 : 1.1)) *
                    h -
                moveButton,
            child: Stack(children: [
              Center(
                  child: SizedBox(
                      width: size * floatingButtonSize,
                      height: size * floatingButtonSize,
                      child: FittedBox(
                          fit: BoxFit.contain,
                          child: Text("$extraMovesLeft",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: extraMovesLeft > 0
                                    ? Colors.green[900]
                                    : Colors.red[900],
                              ))))),
              SizedBox(
                  width: size * floatingButtonSize,
                  height: size * floatingButtonSize,
                  child: FittedBox(
                    child: FloatingActionButton(
                        splashColor: Colors.transparent,
                        heroTag: "ExtraMoves",
                        shape: const CircleBorder(),
                        onPressed: () async {
                          if (playerToMove == myPlayerId &&
                              extraMovesLeft > 0) {
                            extraMovesLeft--;
                            gameDices.nrRolls--;

                            context.read<SetStateCubit>().setState();
                          }
                        },
                        backgroundColor: Colors.blue.withValues(alpha: 0.5),
                        child: FittedBox(
                            fit: BoxFit.contain,
                            child: Text(extraMovesLeft_,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: .5),
                                )))),
                  )),
            ]));
      }

      Widget widget = Stack(children: [
        buttonExtraMoves,
        buttonRegretGame,
        // Start new game immediately as one player
        if (nrPlayers == 1)
          Positioned(
              //key: keySettings,
              left: l + (1.0 - floatingButtonSize * (size == h ? 2 : 1.1)) * w,
              top: t +
                  (1.0 - floatingButtonSize * 2 * (size == w ? 2 : 1.1)) * h -
                  moveButton,
              child: SizedBox(
                  width: size * floatingButtonSize,
                  height: size * floatingButtonSize,
                  child: FittedBox(
                      child: FloatingActionButton(
                    splashColor: Colors.transparent,
                    heroTag: "NewGame",
                    shape: const CircleBorder(),
                    onPressed: () async {
                      if (nrPlayers == 1) {
                        myPlayerId = 0;
                        gameId = 0;
                        playerIds = [""];
                        playerActive = List.filled(playerIds.length, true);
                        nrPlayers = 1;
                        setup();
                        userNames = [userName];
                        animation.players = 1;
                        if (gameDices.rollDices(context)) {
                          gameDices.animationController.forward();
                        }
                        context.read<SetStateCubit>().setState();
                      }
                    },
                    tooltip: restart_,
                    backgroundColor: Colors.blue.withValues(alpha: 0.5),
                    child: const Icon(Icons.restart_alt),
                  )))),
        Positioned(
            key: keySettings,
            left: l + (1.0 - floatingButtonSize * (size == h ? 2 : 1.1)) * w,
            top: t +
                (1.0 - floatingButtonSize * (size == w ? 2 : 1.1)) * h -
                moveButton,
            child: SizedBox(
                width: size * floatingButtonSize,
                height: size * floatingButtonSize,
                child: FittedBox(
                    child: FloatingActionButton(
                  heroTag: "NavigateSettings",
                  shape: const CircleBorder(),
                  onPressed: () async {
                    await AutoRouter.of(context).push(const SettingsView());
                  },
                  tooltip: settings_,
                  backgroundColor: Colors.blue.withValues(alpha: 0.5),
                  child: const Icon(Icons.settings_applications),
                ))))
      ]);

      return widget;
    }

    gameFinished = true;
    for (var i = 0; i < playerActive.length; i++) {
      if (playerActive[i]) {
        if (fixedCell[i].contains(false)) {
          gameFinished = false;
          break;
        }
      }
    }

    stackedWidgets = [];
    if (!gameDices.unityDices &&
        mainPageLoaded &&
        isTutorial &&
        callbackCheckPlayerToMove() &&
        gameDices.nrRolls < 3) {
      stackedWidgets = [
        tutorial.widgetArrow(gameDices.rollDiceKey, w, h,
            tutorial.animationController1, gameDices.pressToRoll_, 0, "R", 0.5)
      ];
      if (!tutorial.animationController1.isAnimating) {
        tutorial.animationController1.repeat(reverse: true);
      }
    }

    if (!gameDices.unityDices &&
        mainPageLoaded &&
        isTutorial &&
        callbackCheckPlayerToMove() &&
        (gameDices.nrRolls == 1 || gameDices.nrRolls == 2)) {
      stackedWidgets.add(tutorial.widgetArrow(gameDices.holdDiceKey[0], w, h,
          tutorial.animationController2, gameDices.pressToHold_, 1, "B", 0.5));
      if (!tutorial.animationController2.isAnimating) {
        tutorial.animationController2.repeat(reverse: true);
      }
    }

    if (mainPageLoaded &&
        isTutorial &&
        callbackCheckPlayerToMove() &&
        gameDices.nrRolls == 3) {
      stackedWidgets.add(tutorial.widgetArrow(
          cellKeys[myPlayerId + 1][totalFields - 5],
          w,
          h,
          tutorial.animationController2,
          chooseMove_,
          1,
          "R",
          devicePixelRatio > 2.5 ? 1.0 : 1.5));
      if (!tutorial.animationController2.isAnimating) {
        tutorial.animationController2.repeat(reverse: true);
      }
    }
    try {
      if (mainPageLoaded && isTutorial && gameFinished) {
        stackedWidgets.add(tutorial.widgetArrow(keySettings, w, h,
            tutorial.animationController3, pressSettings_, 2, "L", 0.5));
        if (!tutorial.animationController3.isAnimating) {
          tutorial.animationController3.repeat(reverse: true);
        }
      }
    } catch (e) {
      // Error
    }

    if (h > w) {
      return Scaffold(
          body: Stack(children: <Widget>[
        Image.asset("assets/images/yatzy_portrait.jpg",
            fit: BoxFit.cover, height: double.infinity, width: double.infinity),
        Stack(children: [
          Positioned(
              left: l,
              top: h * 0.75 + t,
              child: WidgetDices(width: w, height: h * 0.25)),
          Positioned(
              left: w * 0.35 + l,
              top: h * 0.0 + t,
              child: WidgetTopScore(width: w * 0.30, height: h * 0.2)),
          Positioned(
              left: l,
              top: h * 0.20 + t,
              child: WidgetSetupGameBoard(width: w, height: h * 0.55)),
          Positioned(
              left: w * 0.025 + l,
              top: h * 0.04 + t,
              child: WidgetDisplayGameStatus(width: w * 0.3, height: h * 0.16)),
          Positioned(
              left: w * 0.675 + l,
              top: h * 0.04 + t,
              child: WidgetChat(width: w * 0.30, height: h * 0.16)),
          WidgetAnimationsScroll(
              width: w,
              height: h * 0.1,
              left: w * 0.025 + l,
              top: -h * 0.03 + t)
        ]),
        widgetFloatingButton(h),
        Stack(children: stackedWidgets),
      ]));
    } else {
      // landscape

      return Scaffold(
          body: Stack(children: <Widget>[
        Image.asset("assets/images/yatzy_landscape2.jpg",
            fit: BoxFit.cover, height: double.infinity, width: double.infinity),
        Stack(children: [
          Positioned(
              left: w * 0.32 + l,
              top: h * 0.32 + t,
              child: WidgetDices(width: w * 0.625, height: h * 0.68)),
          Positioned(
              left: w * 0.81 + l,
              top: h * 0.02 + t,
              child: WidgetTopScore(width: w * 0.18, height: h * 0.3)),
          Positioned(
              left: l,
              top: t,
              child: WidgetSetupGameBoard(width: w * 0.35, height: h)),
          Positioned(
              left: w * 0.35 + l,
              top: h * 0.02 + t,
              child: WidgetDisplayGameStatus(width: w * 0.2, height: h * 0.3)),
          Positioned(
              left: w * 0.575 + l,
              top: h * 0.02 + t,
              child: WidgetChat(width: w * 0.22, height: h * 0.3)),
          WidgetAnimationsScroll(
              width: w * 0.43,
              height: h * 0.2,
              left: w * 0.355 + l,
              top: -h * 0.07 + t)
        ]),
        widgetFloatingButton(w),
        Stack(children: stackedWidgets),
      ]));
    }
  }
}
