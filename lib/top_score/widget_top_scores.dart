import 'package:flutter/material.dart';
import '../startup.dart';
import 'languages_top_score.dart';

class WidgetTopScore extends StatefulWidget {
  final double width;
  final double height;

  const WidgetTopScore({super.key, required this.width, required this.height});

  @override
  State<WidgetTopScore> createState() => _WidgetTopScoreState();
}

class _WidgetTopScoreState extends State<WidgetTopScore>
    with TickerProviderStateMixin, LanguagesTopScore {
  setupAnimation(TickerProvider ticket) {
    topScore.animationController = AnimationController(
        vsync: ticket, duration: const Duration(milliseconds: 3000));
    topScore.loopAnimation = CurveTween(curve: Curves.easeInSine)
        .animate(topScore.animationController);

    topScore.animationController.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        topScore.animationController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        topScore.animationController.forward();
      }
    });
    topScore.animationController.forward();
  }

  @override
  void initState() {
    super.initState();
    languagesSetup(topScore.getChosenLanguage(), topScore.standardLanguage());
    setupAnimation(this);
  }

  @override
  void dispose() {
    super.dispose();
    topScore.animationController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double width = widget.width;
    double height = widget.height;

    var containerWidth = width;
    var heightCaption = height / 6.4;
    var containerHeight = height - heightCaption;
    var left = 0.0, top = 0.0;

    List<Widget> listings = <Widget>[];

    listings.add(Positioned(
        left: left,
        top: top,
        child: Container(
            padding:
                const EdgeInsets.only(left: 20, right: 20, top: 0, bottom: 0),
            width: containerWidth,
            height: heightCaption,
            //child: Center(
            child: FittedBox(
                fit: BoxFit.contain,
                child: Text(topScores_,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.blue[800],
                      shadows: const [
                        Shadow(
                          blurRadius: 10.0,
                          color: Colors.red,
                          offset: Offset(5.0, 5.0),
                        ),
                      ],
                    ))))));
    try {
      listings.add(AnimatedBuilder(
          animation: topScore.animationController,
          builder: (BuildContext context, Widget? widget) {
            return Positioned(
              left: left,
              top: top + heightCaption,
              child: Container(
                width: containerWidth,
                height: containerHeight,
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.redAccent),
                    borderRadius: BorderRadius.circular(10.0),
                    gradient: LinearGradient(
                      colors: [
                        Colors.greenAccent.withValues(alpha: 0.5),
                        Colors.lightBlueAccent.withValues(alpha: 0.5)
                      ],
                      stops: [0.0, topScore.loopAnimation.value],
                    )),
                child: Scrollbar(
                  //showTrackOnHover: true,
                  child: ListView.builder(
                      primary: true,
                      padding: const EdgeInsets.all(4),
                      itemCount: topScore.topScores.length,
                      itemBuilder: (BuildContext context, int index) {
                        return Container(
                          height: heightCaption,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.blueAccent),
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                    padding: const EdgeInsets.only(
                                        left: 0, right: 5, top: 0, bottom: 0),
                                    width: containerWidth * 0.15,
                                    child: FittedBox(
                                        fit: BoxFit.contain,
                                        child: Text("  ${index + 1}.",
                                            style: const TextStyle(
                                                fontStyle: FontStyle.italic,
                                                color: Colors.black54)))),
                                Container(
                                    padding: const EdgeInsets.only(
                                        left: 5, right: 5, top: 0, bottom: 0),
                                    width: containerWidth * 0.5,
                                    child: FittedBox(
                                        fit: BoxFit.contain,
                                        child: Text(
                                            topScore.topScores[index]["name"],
                                            style: const TextStyle(
                                                //fontWeight: FontWeight.bold,
                                                color: Colors.black)))),
                                Container(
                                    padding: const EdgeInsets.only(
                                        left: 5, right: 0, top: 0, bottom: 0),
                                    width: containerWidth * 0.25,
                                    child: FittedBox(
                                        fit: BoxFit.contain,
                                        child: Text(
                                            "${topScore.topScores[index]["score"]}  ",
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.redAccent))))
                              ]),
                        );
                      }),
                ),
              ),
            );
          }));
    } catch (e) {
      // error
    }
    return SizedBox(
        width: width, height: height, child: Stack(children: listings));
  }
}
