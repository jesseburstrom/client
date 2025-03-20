mixin LanguagesTopScore {
  late Function _getChosenLanguage;
  late String _standardLanguage;

  final _topScores = {"English": "Top Scores"};

  String get topScores_ => getText(_topScores);

  void languagesSetup(Function getChosenLanguage, String standardLanguage) {
    _getChosenLanguage = getChosenLanguage;
    _standardLanguage = standardLanguage;

    _topScores["Swedish"] = "Topplista";
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
