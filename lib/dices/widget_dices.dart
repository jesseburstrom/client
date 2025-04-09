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

  late AnimationController _localAnimationController;
  late Animation<double> _localSizeAnimation;

  @override
  void initState() {
    super.initState();
    _localAnimationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _localSizeAnimation =
        CurveTween(curve: Curves.easeInSine).animate(_localAnimationController);

    _localAnimationController.addStatusListener((AnimationStatus status) {
      if (!mounted) return;
      if (status == AnimationStatus.completed) {
        _localAnimationController.reverse();
      }
    });
    //setupAnimation(this);
  }

  @override
  void dispose(){
    print("Disposing WidgetDicesState...");
    try {
      _localAnimationController.stop();
      _localAnimationController.dispose();
      print("Disposed local WidgetDices controller.");
    } catch (e) { print("Error disposing local WidgetDices controller: $e"); }
    super.dispose();
  }

  // --- ADD Reusable Dice Face Widget Builder ---
  // Takes the dice value (1-6) and the desired size for the dice face container
  static Widget buildDiceFace(int value, double diceSize) {
    final double dotSize = diceSize * 0.18; // Size of each dot
    final double padding = diceSize * 0.1;  // Padding around dots/groups

    Widget dot = Container(
      width: dotSize,
      height: dotSize,
      decoration: const BoxDecoration(
        color: Colors.black,
        shape: BoxShape.circle, // Make dots circular
      ),
    );

    List<Widget> children;

    switch (value) {
      case 1:
        children = [Center(child: dot)];
        break;
      case 2:
        children = [
          Align(alignment: Alignment.topLeft, child: Padding(padding: EdgeInsets.all(padding), child: dot)),
          Align(alignment: Alignment.bottomRight, child: Padding(padding: EdgeInsets.all(padding), child: dot)),
        ];
        break;
      case 3:
        children = [
          Align(alignment: Alignment.topLeft, child: Padding(padding: EdgeInsets.all(padding), child: dot)),
          Center(child: dot),
          Align(alignment: Alignment.bottomRight, child: Padding(padding: EdgeInsets.all(padding), child: dot)),
        ];
        break;
      case 4:
        children = [
          Align(alignment: Alignment.topLeft, child: Padding(padding: EdgeInsets.all(padding), child: dot)),
          Align(alignment: Alignment.topRight, child: Padding(padding: EdgeInsets.all(padding), child: dot)),
          Align(alignment: Alignment.bottomLeft, child: Padding(padding: EdgeInsets.all(padding), child: dot)),
          Align(alignment: Alignment.bottomRight, child: Padding(padding: EdgeInsets.all(padding), child: dot)),
        ];
        break;
      case 5:
        children = [
          Align(alignment: Alignment.topLeft, child: Padding(padding: EdgeInsets.all(padding), child: dot)),
          Align(alignment: Alignment.topRight, child: Padding(padding: EdgeInsets.all(padding), child: dot)),
          Center(child: dot),
          Align(alignment: Alignment.bottomLeft, child: Padding(padding: EdgeInsets.all(padding), child: dot)),
          Align(alignment: Alignment.bottomRight, child: Padding(padding: EdgeInsets.all(padding), child: dot)),
        ];
        break;
      case 6:
        children = [
          Align(alignment: Alignment.topLeft, child: Padding(padding: EdgeInsets.all(padding), child: dot)),
          Align(alignment: Alignment.topRight, child: Padding(padding: EdgeInsets.all(padding), child: dot)),
          Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.only(left: padding), child: dot)),
          Align(alignment: Alignment.centerRight, child: Padding(padding: EdgeInsets.only(right: padding), child: dot)),
          Align(alignment: Alignment.bottomLeft, child: Padding(padding: EdgeInsets.all(padding), child: dot)),
          Align(alignment: Alignment.bottomRight, child: Padding(padding: EdgeInsets.all(padding), child: dot)),
        ];
        break;
      default: // Handle 0 or invalid values - show empty
        children = [];
        break;
    }

    // Return the dots within a Stack to allow positioning
    return Stack(children: children);
  }
  // --- END Dice Face Builder ---

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
                //webUrl: '/UnityLibrary/index.html',
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

    double diceWidgetSize = 4 * width / (5 * app.gameDices.nrDices + 1);
    left = diceWidgetSize / 4;
    top = min(diceWidgetSize / 2,
        diceWidgetSize / 2 + (height - diceWidgetSize * 3.5) / 2);

    for (var i = 0; i < app.gameDices.nrDices; i++) {
      // Boundary check for diceValue array
      int diceValue = (i < app.gameDices.diceValue.length) ? app.gameDices.diceValue[i] : 0;

      listings.add(
        Positioned(
            left: left + 1.25 * diceWidgetSize * i,
            top: top,
            child: GestureDetector( // Keep GestureDetector for hold functionality
              onTap: () {
                if (app.callbackCheckPlayerToMove()) { // Only allow hold if it's my turn
                  app.gameDices.holdDice(i);
                  app.gameDices.setState(); // This should trigger a rebuild via Bloc
                }
              },
              child: Container(
                width: diceWidgetSize,
                height: diceWidgetSize,
                decoration: BoxDecoration(
                    color: Colors.white, // White background for dice
                    borderRadius: BorderRadius.circular(diceWidgetSize * 0.15), // Rounded corners
                    border: Border.all(color: Colors.grey.shade400),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 3,
                        offset: const Offset(1, 2),
                      )
                    ]
                ),
                // --- Use the new dice face builder ---
                child: buildDiceFace(diceValue, diceWidgetSize),
                // --------------------------------------
              ),
            )),
      );

      // Add the "HOLD" overlay if needed
      // Boundary check for holdDiceOpacity and holdDiceText
      double holdOpacity = (i < app.gameDices.holdDiceOpacity.length) ? app.gameDices.holdDiceOpacity[i] : 0.0;
      String holdText = (i < app.gameDices.holdDiceText.length) ? app.gameDices.holdDiceText[i] : "";

      if (holdOpacity > 0) {
        listings.add(Positioned(
          left: left + 1.25 * diceWidgetSize * i,
          top: top,
          child: IgnorePointer( // Makes overlay non-interactive
            child: Container(
              width: diceWidgetSize,
              height: diceWidgetSize,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: holdOpacity * 0.7), // Adjust opacity
                borderRadius: BorderRadius.circular(diceWidgetSize * 0.15),
              ),
              child: Center(
                child: Text(
                  holdText,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.bold,
                    fontSize: diceWidgetSize * 0.3, // Scale text size
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ));
      }
    }

    // --- Update Roll button ---
    listings.add(AnimatedBuilder(
      animation: _localAnimationController, // Use local controller
      builder: (BuildContext context, Widget? builderWidget) { // Renamed widget parameter
        final bool canRoll = !app.gameFinished &&
            app.callbackCheckPlayerToMove() &&
            app.gameDices.nrRolls < app.gameDices.nrTotalRolls;

        // Calculate button size based on animation
        double buttonScaleFactor = (1 - _localSizeAnimation.value / 2);
        double buttonSize = diceWidgetSize * 1.5; // Make button a bit larger than dice

        return Positioned(
          // Center the button roughly, adjust vertical position
          left: left + (width / 2) - (buttonSize * buttonScaleFactor / 2) - (diceWidgetSize/4), // Centering adjustment
          top: top + diceWidgetSize * 1.5, // Position below the dice row
          child: SizedBox( // Use SizedBox to apply animated size
            width: buttonSize * 0.8 * buttonScaleFactor, // Make button more square
            height: buttonSize * 0.8 * buttonScaleFactor, // Make button more square
            child: ElevatedButton(
              onPressed: canRoll ? () {
                if (app.gameDices.rollDices(context)) {
                  _localAnimationController.forward(); // Start local animation
                }
              } : null, // Disable button if cannot roll
              style: ElevatedButton.styleFrom(
                backgroundColor: canRoll ? Colors.red.shade600 : Colors.grey.shade500,
                foregroundColor: Colors.white,
                shape: const CircleBorder(), // Make it circular for a classic roll feel
                padding: EdgeInsets.zero, // Remove padding to center icon
                elevation: canRoll ? 4 : 0,
              ),
              // --- Use Icon instead of Label ---
              child: Icon(
                // Option 1: Send/Throw motion
                  Icons.send,
                  // Option 2: Replay/Re-roll symbol
                  // Icons.replay,
                  // Option 3: Casino/Dice symbol
                  // Icons.casino_outlined, // Kept this as an option too
                  size: buttonSize * 0.4 * buttonScaleFactor // Adjust icon size
              ),
              // ---------------------------------
            ),
          ),
        );
      },
    ));
    // --- End Roll button update ---

    return SizedBox(
        width: width, height: height, child: Stack(children: listings));
  }
}
