class LanguagesDices{
  late Function _getChosenLanguage;
  late String _standardLanguage;

  final _hold = {"English": "HOLD"};
  final _rollsLeft = {"English": "Rolls left"};
  final _transparency = {"English": "Transparency"};
  final _lightMotion = {"English": "Light Motion"};
  final _red = {"English": "Red"};
  final _green = {"English": "Green"};
  final _blue = {"English": "Blue"};
  final _choseUnity = {"English": "3D Dices"};
  final _colorChangeOverlay = {"English": "Color Change Overlay"};
  final _fun = {"English": "Fun!"};
  final _snowEffect = {"English": "Snow Effect"};
  final _pressToRoll = {"English": "\nPress To Roll"};
  final _pressToHold = {"English": "Press To \nHold/UnHold"};

  String get choseUnity_ => getText(_choseUnity);

  String get colorChangeOverlay_ => getText(_colorChangeOverlay);

  String get hold_ => getText(_hold);

  String get transparency_ => getText(_transparency);

  String get lightMotion_ => getText(_lightMotion);

  String get red_ => getText(_red);

  String get green_ => getText(_green);

  String get blue_ => getText(_blue);

  String get rollsLeft_ => getText(_rollsLeft);

  String get fun_ => getText(_fun);

  String get snowEffect_ => getText(_snowEffect);

  String get pressToRoll_ => getText(_pressToRoll);

  String get pressToHold_ => getText(_pressToHold);

  void languagesSetup(Function getChosenLanguage, String standardLanguage) {
    _getChosenLanguage = getChosenLanguage;
    _standardLanguage = standardLanguage;
    _choseUnity["Swedish"] = "3D Tärningar";
    _colorChangeOverlay["Swedish"] = "Färginställningar Live";
    _hold["Swedish"] = "HÅLL";
    _rollsLeft["Swedish"] = "Kast kvar";
    _transparency["Swedish"] = "Transparens";
    _lightMotion["Swedish"] = "Cirkulärt Ljus";
    _red["Swedish"] = "Röd";
    _green["Swedish"] = "Grön";
    _blue["Swedish"] = "Blå";
    _rollsLeft["Swedish"] = "Kast kvar";
    _fun["Swedish"] = "Kul!";
    _snowEffect["Swedish"] = "Snö Effekt";
    _pressToRoll["Swedish"] = "Tryck För Att \nKasta";
    _pressToHold["Swedish"] = "Tryck För Att \nHålla/Släppa";
  }

  String getText(var textVariable) {
    var text = textVariable[_getChosenLanguage()];
    if (text != null) {
      return text;
    } else {
      return textVariable[_standardLanguage]!;
    }
  }
}
