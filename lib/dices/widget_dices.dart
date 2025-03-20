import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_unity_widget/flutter_unity_widget.dart';
import '../startup.dart';
import 'unity_communication.dart';

class WidgetDices extends StatefulWidget {
  final double width;
  final double height;

  const WidgetDices({super.key, required this.width, required this.height});

  @override
  State<WidgetDices> createState() => _WidgetDicesState();
}

class _WidgetDicesState extends State<WidgetDices>
    with TickerProviderStateMixin {

  setupAnimation(TickerProvider ticket) {
    app.gameDices.animationController = AnimationController(
        vsync: ticket, duration: const Duration(milliseconds: 300));
    app.gameDices.sizeAnimation =
        CurveTween(curve: Curves.easeInSine).animate(app.gameDices.animationController);

    app.gameDices.animationController.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        app.gameDices.animationController.reverse();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    setupAnimation(this);
  }

  @override
  void dispose(){
    super.dispose();
    app.gameDices.animationController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double width = widget.width;
    double height = widget.height;
    // First always start unity and hide if only 2D
    // Get best 16:9 fit
    var left = 0.0, top = 0.0, w = width, h = height, ratio = 16 / 9;
    if (w > h) {
      if (width / height < ratio) {
        h = width / ratio;
        top = (height - h) / 2;
      } else {
        w = height * ratio;
        left = (width - w) / 2;
      }
    } else {
      // topple screen, calculate best fit, topple back
      var l_ = 0.0, t_ = 0.0, w_ = height, h_ = width;

      if (height / width < ratio) {
        h_ = height / ratio;
        t_ = (width - h_) / 2;
      } else {
        w_ = width * ratio;
        l_ = (height - w_) / 2;
      }

      h = w_;
      w = h_;
      left = t_;
      top = l_;
    }

    if (app.gameDices.unityDices) {
      Widget widgetUnity = Positioned(
          left: left,
          top: top,
          child: SizedBox(
              // Add 75 to subtract at canvas to avoid scrollbars
              width: w + 75,
              height: h + 75,
              child: UnityWidget(
                borderRadius: BorderRadius.zero,
                onUnityCreated: app.gameDices.onUnityCreated,
                onUnityMessage: app.gameDices.onUnityMessage,
                onUnityUnloaded: app.gameDices.onUnityUnloaded,
                onUnitySceneLoaded: app.gameDices.onUnitySceneLoaded,
                fullscreen: false,
              )));

      return SizedBox(
          width: width, height: height, child: Stack(children: [widgetUnity]));
    }

    var listings = <Widget>[];

    double diceWidthHeight = 4 * width / (5 * app.gameDices.nrDices + 1);
    left = diceWidthHeight / 4;
    top = min(diceWidthHeight / 2,
        diceWidthHeight / 2 + (height - diceWidthHeight * 3.5) / 2);

    for (var i = 0; i < app.gameDices.nrDices; i++) {
      listings.add(
        Positioned(
            left: left + 1.25 * diceWidthHeight * i,
            top: top,
            child: Container(
              width: diceWidthHeight,
              height: diceWidthHeight,
              decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.3)),
              child: Image.asset(app.gameDices.diceRef[i]),
            )),
      );
      listings.add(Positioned(
        key: app.gameDices.holdDiceKey[i],
        left: left + 1.25 * diceWidthHeight * i,
        top: top,
        child: GestureDetector(
            onTap: () {
              app.gameDices.holdDice(i);

              app.gameDices.setState();
            },
            child: Container(
              width: diceWidthHeight,
              height: diceWidthHeight,
              decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 
                      app.gameDices.holdDiceOpacity.isNotEmpty
                          ? app.gameDices.holdDiceOpacity[i]
                          : 0.44)),
              child: FittedBox(
                alignment: Alignment.bottomCenter,
                fit: BoxFit.contain,
                child: Text(
                  app.gameDices.holdDiceText.isNotEmpty
                      ? app.gameDices.holdDiceText[i]
                      : "HOLD",
                  style: TextStyle(
                    color: Colors.black87.withValues(alpha: 0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )),
      ));
    }

    // Roll button

    listings.add(AnimatedBuilder(
      animation: app.gameDices.animationController,
      builder: (BuildContext context, Widget? widget) {
        final tmp = Listener(
            onPointerDown: (e) {
              if (!app.callbackCheckPlayerToMove()) {
                return;
              }
              if (app.gameDices.rollDices(context)) {
                app.gameDices.animationController.forward();

                app.gameDices.setState();
              }
            },
            child: Container(
              width: diceWidthHeight * (1 - app.gameDices.sizeAnimation.value / 2),
              height: diceWidthHeight * (1 - app.gameDices.sizeAnimation.value / 2),
              decoration: const BoxDecoration(color: Colors.red),
              child: Image.asset("assets/images/roll.jpg",
                  fit: BoxFit.cover,
                  height: double.infinity,
                  width: double.infinity),
            ));
        return Positioned(
          key: app.gameDices.rollDiceKey,
          left: left +
              diceWidthHeight * ((app.gameDices.sizeAnimation.value) / 4) +
              width / 2 -
              diceWidthHeight * 3 / 4,
          top: top +
              diceWidthHeight * (app.gameDices.sizeAnimation.value / 4) +
              1.5 * diceWidthHeight,
          child: tmp,
        );
      },
    ));

    return SizedBox(
        width: width, height: height, child: Stack(children: listings));
  }
}
