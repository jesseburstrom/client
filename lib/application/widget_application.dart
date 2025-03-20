import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yatzy/application/application_functions_internal.dart';
import 'package:yatzy/dices/unity_communication.dart';

import '../startup.dart';
import '../states/cubit/state/state_cubit.dart';

import 'languages_application.dart';


class WidgetSetupGameBoard extends StatefulWidget {
  final double width;
  final double height;

  const WidgetSetupGameBoard(
      {super.key, required this.width, required this.height});

  @override
  State<WidgetSetupGameBoard> createState() =>
      _WidgetSetupGameBoardState();
}

class _WidgetSetupGameBoardState extends State<WidgetSetupGameBoard> with LanguagesApplication {
  @override
  void initState() {
    super.initState();
    //languagesSetup(app.getChosenLanguage(), app.standardLanguage());
  }

  @override
  Widget build(BuildContext context) {
    double width = widget.width;
    double height = widget.height;

    var cellWidth = min(250, width / ((app.nrPlayers) / 3 + 1.5));
    //var cellHeight = min(30.0, height / (TotalFields + 1));

    var cellHeight = height / (app.totalFields + 1.5);
    cellWidth = min(cellWidth, cellHeight * 5);

    var top = (height - cellHeight * app.totalFields) * 0.75;
    var left = (width - cellWidth * ((app.nrPlayers - 1) / 3 + 1.5)) / 2;

    if (app.boardWidth.isEmpty) {
      app.setup();
    }
    // Setup board cell positions
    for (var i = 0; i < app.totalFields; i++) {
      app.boardWidth[0][i] = cellWidth;
      app.boardHeight[0][i] = cellHeight;
      app.boardXPos[0][i] = left;
      app.boardYPos[0][i] = i * cellHeight + top;
    }

    for (var i = 0; i < app.nrPlayers; i++) {
      for (var j = 0; j < app.totalFields; j++) {
        app.boardXPos[i + 1][j] = app.boardXPos[i][j] +app.boardWidth[i][j];
        app.boardYPos[i + 1][j] = app.boardYPos[0][j];
        app.boardHeight[i + 1][j] = app.boardHeight[0][j];
        app.boardWidth[i + 1][j] = app.boardWidth[0][j] / 3;
      }
    }

    for (var i = 0; i < app.nrPlayers; i++) {
      for (var j = 0; j < app.totalFields; j++) {
        // enlarge dimension of cell in focus
        if (app.focusStatus[i][j] == 1) {
          app.boardXPos[i + 1][j] -= app.boardWidth[i + 1][j] / 2;
          app.boardWidth[i + 1][j] *= 2;
          app.boardYPos[i + 1][j] -= app.boardHeight[i + 1][j] / 2;
          app.boardHeight[i + 1][j] *= 2;
        }
      }
    }

    var listings = <Widget>[];

    // Place names
    for (var i = 0; i < app.nrPlayers; i++) {
      listings.add(Positioned(
          left: app.boardXPos[1 + i][0],
          top: app.boardYPos[1 + i][0] - cellHeight,
          child: Container(
              padding:
              const EdgeInsets.only(left: 5, right: 5, top: 0, bottom: 0),
              width: app.boardWidth[1 + i][0],
              height: cellHeight,
              child: FittedBox(
                  fit: BoxFit.contain,
                  child: Text(
                      userNames.length > i && userNames[i].isNotEmpty
                          ? userNames[i].length > 3
                              ? userNames[i].substring(0, 3)
                              : userNames[i]
                          : "P${i+1}",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Colors.black.withValues(alpha: 0.8),
                        shadows: const [
                          Shadow(
                            blurRadius: 10.0,
                            color: Colors.blueAccent,
                            offset: Offset(5.0, 5.0),
                          ),
                        ],
                      ))))));
    }
    // For 'live' translation reset board text
    app.setAppText();
    for (var i = 0; i < app.totalFields; i++) {
      try {
        listings.add(
          AnimatedBuilder(
              animation: app.animation.cellAnimationControllers[0][i],
              builder: (BuildContext context, Widget? widget) {
                return Positioned(
                    key: app.cellKeys[0][i],
                    left: app.boardXPos[0][i] + app.animation.boardXAnimationPos[0][i],
                    top: app.boardYPos[0][i] + app.animation.boardYAnimationPos[0][i],
                    child: Container(
                      padding: const EdgeInsets.only(left: 10, right: 10),
                      width: app.boardWidth[0][i],
                      height: app.boardHeight[0][i],
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.grey,
                          width: 1.0,
                        ),
                        color: app.appColors[0][i],
                      ),
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: Text(
                          app.appText[0][i],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            //color: Colors.blue[800],
                            shadows: [
                              Shadow(
                                blurRadius: 5.0,
                                color: Colors.blue,
                                offset: Offset(2.0, 2.0),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ));
              }),
        );
      } catch (e) {
        // error
      }
    }

    onVerticalDragUpdate(mainX, mainY) {
      if (app.playerToMove != app.myPlayerId) {
        return;
      }
      var box = app.listenerKey.currentContext!.findRenderObject() as RenderBox;
      var position = box.localToGlobal(Offset.zero); //this is global position
      mainY -= position.dy;
      for (var i = 0; i < app.totalFields; i++) {
        if (mainY >= app.boardYPos[0][i] &&
            mainY <= app.boardYPos[0][i] + app.boardHeight[0][i]) {
          if (!app.fixedCell[app.playerToMove][i] && app.cellValue[app.playerToMove][i] != -1) {
            if (app.focusStatus[app.playerToMove][i] == 0) {
              app.clearFocus();
              app.focusStatus[app.playerToMove][i] = 1;
            }
          }
        }
      }
    }

    //add listener object to get drag positions
    //Important it comes after the part over which it should trigger
    listings.add(GestureDetector(
        key: app.listenerKey,
        onVerticalDragUpdate: (d) {
          onVerticalDragUpdate(d.globalPosition.dx, d.globalPosition.dy);

          context.read<SetStateCubit>().setState();
        },
        onTap: () {
          app.clearFocus();

          context.read<SetStateCubit>().setState();
        },
        child: SizedBox(width: width, height: height, child: const Text(""))));

    Widget? focusWidget;
    Widget tmpWidget;

    try {
      for (var i = 0; i < app.nrPlayers; i++) {
        for (var j = 0; j < app.totalFields; j++) {
          tmpWidget = AnimatedBuilder(
              animation: app.animation.cellAnimationControllers[i][j],
              builder: (BuildContext context, Widget? widget) {
                return Positioned(
                  key: app.cellKeys[i + 1][j],
                  left: app.boardXPos[i + 1][j] +
                      app.animation.boardXAnimationPos[i + 1][j],
                  top: app.boardYPos[i + 1][j] +
                      app.animation.boardYAnimationPos[i + 1][j],
                  child: GestureDetector(
                      onTap: () {
                        app.cellClick(i, j);

                        context.read<SetStateCubit>().setState();
                      },
                      child: Container(
                          width: app.boardWidth[i + 1][j],
                          height: app.boardHeight[i + 1][j],
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.blue,
                            ),
                            borderRadius: BorderRadius.circular(10.0),
                            color: app.appColors[i + 1][j],
                          ),
                          child: FittedBox(
                            fit: BoxFit.fitHeight,
                            child: Text(app.appText[i + 1][j],
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ))),
                );
              });
          if (app.focusStatus[i][j] == 1) {
            focusWidget = tmpWidget;
          } else {
            listings.add(tmpWidget);
          }
        }
      }

      // The focus widget is overlapping neighbor widgets
      // it needs to be last to have priority
      if (focusWidget != null) {
        listings.add(focusWidget);
      }
    } catch (e) {
      // Error
    }
    return SizedBox(
        width: screenWidth, height: height, child: Stack(children: listings));
  }
}

class WidgetDisplayGameStatus extends StatefulWidget {
  final double width;
  final double height;

  const WidgetDisplayGameStatus(
      {super.key, required this.width, required this.height});

  @override
  State<WidgetDisplayGameStatus> createState() =>
      _WidgetDisplayGameStatusState();
}

class _WidgetDisplayGameStatusState extends State<WidgetDisplayGameStatus> with LanguagesApplication{
  @override
  void initState() {
    super.initState();
    languagesSetup(app.getChosenLanguage(), app.getStandardLanguage());
  }

  @override
  Widget build(BuildContext context) {
    double width = widget.width;
    double height = widget.height;
    // If all active player(s) finished calculate winner

    if (app.gameFinished && app.gameStarted) {
      app.gameStarted = false;
      if (app.gameDices.unityDices) {
        app.gameDices.sendResetToUnity();
      }
    }

    var playerName = app.playerToMove == app.myPlayerId ? your_ : 
        (userNames.length > app.playerToMove && userNames[app.playerToMove].isNotEmpty 
          ? "${userNames[app.playerToMove]}'s" 
          : "Player ${app.playerToMove + 1}'s");
    var outputText = app.gameFinished ? gameFinished_ : "$playerName $turn_ ";

    Widget myWidget = Container(
        width: width,
        height: height,
        color: Colors.white.withValues(alpha: 0.3),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                  width: width,
                  height: height * 0.4,
                  child: AutoSizeText(outputText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: width / 5,
                          color: Colors.blueGrey))),
              if (app.myPlayerId != -1)
                SizedBox(
                    width: width,
                    height: height * 0.2,
                    child: FittedBox(
                        fit: BoxFit.contain,
                        child: Text(
                            "${app.gameDices.rollsLeft_}: ${(app.gameDices.nrTotalRolls - app.gameDices.nrRolls).toString()}",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey))))
            ]));
    return myWidget;
  }
}
