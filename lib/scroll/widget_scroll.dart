import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';

import '../startup.dart';
import 'languages_animations_scroll.dart';

class WidgetAnimationsScroll extends StatefulWidget {
  final double width;
  final double height;
  final double left;
  final double top;

  const WidgetAnimationsScroll({super.key, required this.width, required this.height, required this.left, required this.top});

  @override
  State<WidgetAnimationsScroll> createState() => _WidgetAnimationsScrollState();
}

class _WidgetAnimationsScrollState extends State<WidgetAnimationsScroll>
    with TickerProviderStateMixin, LanguagesAnimationsScroll {
  setupAnimation(TickerProvider ticket) {
    animationsScroll.animationController = AnimationController(
        vsync: ticket, duration: const Duration(seconds: 1));
    animationsScroll.positionAnimation =
        CurveTween(curve: Curves.linear).animate(animationsScroll.animationController);

    animationsScroll.animationController.addListener(() {

      animationsScroll.keyYPos = animationsScroll.positionAnimation.value * 30;
    });
  }

  @override
  void initState() {
    super.initState();
    languagesSetup(animationsScroll.getChosenLanguage(), animationsScroll.standardLanguage());
    setupAnimation(this);
    animationsScroll.animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    super.dispose();
    animationsScroll.animationController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double width = widget.width;
    double height = widget.height;
    double left = widget.left;
    double top = widget.top;

    try {
      return AnimatedBuilder(
          animation: animationsScroll.animationController,
          builder: (BuildContext context, Widget? widget) {
            List<String> text = scrollText_.split(".");
            List<AnimatedText> animatedTexts = [];
            for (String s in text) {
              animatedTexts.add(FadeAnimatedText(s));
            }

            return
              Positioned(
                  left: left,
                  top: top + animationsScroll.keyYPos,
                  child: SizedBox(
                      width: width, //sizeAnimation,
                      height: height, //scrollHeight,
                      child: FittedBox(
                        child: DefaultTextStyle(
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                            ),
                            child: AnimatedTextKit(
                              animatedTexts: animatedTexts,
                              repeatForever: true,
                            )),
                      )));
          });
    } catch (e) {
      return Container();
    }
  }
}
