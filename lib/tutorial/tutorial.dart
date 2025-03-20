import 'package:flutter/material.dart';

class Tutorial {
  var keyXPos = List.filled(3, 0.0);
  var keyYPos = List.filled(3, 0.0);
  var animationSide = ["R", "R", "R"];

  //var arrowImage = "arrowRight";

  late AnimationController animationController1,
      animationController2,
      animationController3;
  late Animation<double> positionAnimation1,
      positionAnimation2,
      positionAnimation3;

  setup(TickerProvider ticket) {
    animationController1 = AnimationController(
        vsync: ticket, duration: const Duration(seconds: 1));
    positionAnimation1 =
        CurveTween(curve: Curves.linear).animate(animationController1);

    animationController2 = AnimationController(
        vsync: ticket, duration: const Duration(seconds: 1));
    positionAnimation2 =
        CurveTween(curve: Curves.linear).animate(animationController2);

    animationController3 = AnimationController(
        vsync: ticket, duration: const Duration(seconds: 1));
    positionAnimation3 =
        CurveTween(curve: Curves.linear).animate(animationController3);

    animationController1.addListener(() {
      switch (animationSide[0]) {
        case "R":
          keyXPos[0] = positionAnimation1.value;
          break;
        case "B":
          keyYPos[0] = positionAnimation1.value;
          break;
      }
    });

    animationController2.addListener(() {
      switch (animationSide[1]) {
        case "R":
          keyXPos[1] = positionAnimation2.value;
          break;
        case "L":
          keyXPos[1] = -positionAnimation2.value;
          break;
        case "B":
          keyYPos[1] = positionAnimation2.value;
          break;
      }
    });

    animationController3.addListener(() {
      switch (animationSide[2]) {
        case "R":
          keyXPos[2] = positionAnimation3.value;
          break;
        case "L":
          keyXPos[2] = -positionAnimation3.value;
          break;
        case "B":
          keyYPos[2] = positionAnimation3.value;
          break;
      }
    });
  }

  Widget widgetArrow(
      GlobalKey key,
      double w,
      double h,
      AnimationController animationController,
      String text,
      int controller,
      String side,
      double scale) {
    return AnimatedBuilder(
        animation: animationController,
        builder: (BuildContext context, Widget? widget) {
          animationSide[controller] = side;
          final RenderBox renderBox =
              key.currentContext?.findRenderObject() as RenderBox;
          final Size size = renderBox.size;

          Offset position =
              renderBox.localToGlobal(Offset.zero); //this is global position
          // Default from right side
          var left = position.dx + size.width;
          var top = position.dy +
              size.height / 2 -
              size.height * scale -
              size.height * scale / 2;
          var arrowImage = "arrowRight";
          switch (side) {
            case "L":
              arrowImage = "arrowLeft";
              left = position.dx - size.width * 1.5;
              break;
            case "T":
              arrowImage = "arrowTop";
              break;
            case "B":
              arrowImage = "arrowBottom";
              left = position.dx + size.width / 2 - size.width * scale / 2;
              top = position.dy + size.height;
              break;
          }

          Widget tmp;
          if (side == "R" || side == "L") {
            tmp = Column(children: [
              SizedBox(
                  height: size.height * scale,
                  child: FittedBox(
                      fit: BoxFit.fitHeight,
                      child: Text(text,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black.withValues(alpha: 0.8),
                            shadows: const [
                              Shadow(
                                blurRadius: 10.0,
                                color: Colors.blueAccent,
                                offset: Offset(5.0, 5.0),
                              ),
                            ],
                          )))),
              SizedBox(
                  width: size.height * scale * 3,
                  height: size.height * scale,
                  child: Image.asset(
                    "assets/images/$arrowImage.png",
                    fit: BoxFit.fill,
                  ))
            ]);
          } else {
            tmp = Row(children: [
              SizedBox(
                  width: size.width * scale,
                  height: size.height * scale * 3,
                  child: Image.asset(
                    "assets/images/$arrowImage.png",
                    fit: BoxFit.fill,
                  )),
              SizedBox(
                  height: size.height * scale,
                  child: FittedBox(
                      fit: BoxFit.fitHeight,
                      child: Text(text,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black.withValues(alpha: 0.8),
                            shadows: const [
                              Shadow(
                                blurRadius: 10.0,
                                color: Colors.blueAccent,
                                offset: Offset(5.0, 5.0),
                              ),
                            ],
                          )))),
            ]);
          }

          if (side == "T" || side == "B") {
            top = top + keyYPos[controller] * (w > h ? w * 0.02 : h * 0.02);
          } else {
            left = left + keyXPos[controller] * (w > h ? w * 0.02 : h * 0.02);
          }

          return Positioned(left: left, top: top, child: tmp);
        });
  }
}
