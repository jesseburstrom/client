import 'package:flutter/animation.dart';

import 'languages_animations_scroll.dart';

class AnimationsScroll with LanguagesAnimationsScroll {
  final Function _getChosenLanguage;
  final String _standardLanguage;

  AnimationsScroll(
      {required Function getChosenLanguage, required String standardLanguage})
      : _getChosenLanguage = getChosenLanguage,
        _standardLanguage = standardLanguage;

  var keyXPos = 0.0, keyYPos = 0.0;

  late AnimationController animationController;

  late Animation<double> positionAnimation;

  Function getChosenLanguage() {
    return _getChosenLanguage;
  }

  String standardLanguage() {
    return _standardLanguage;
  }
}
