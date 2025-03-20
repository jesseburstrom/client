mixin LanguagesAnimationsScroll {
  late Function _getChosenLanguage;
  late String _standardLanguage;

  final _scrollText = {
    "English":
        "Welcome to my programming system. It is aimed at speeding up device programming. Enabling"
            " multiinteractive application building. YATZY is my test subject. Complicated enough to build a"
            " cool system around."
  };

  String get scrollText_ => getText(_scrollText);

  void languagesSetup(Function getChosenLanguage, String standardLanguage) {
    _getChosenLanguage = getChosenLanguage;
    _standardLanguage = standardLanguage;
    _scrollText["Swedish"] =
        "Välkommen till mitt programmeringssystem. Det är utvecklat för att snabba upp programmering."
        " Möjliggöra multiinteraktiv applikations utveckling. YATZY är mitt test program. Tillräckligt komplicerat"
        " för att bygga ett coolt system kring.";
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
