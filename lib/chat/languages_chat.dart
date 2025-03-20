mixin LanguagesChat {
  late Function _getChosenLanguage;
  late String _standardLanguage;

  final _sendMessage = {"English": "Send message..."};

  String get sendMessage_ => getText(_sendMessage);

  void languagesSetup(Function getChosenLanguage, String standardLanguage) {
    _getChosenLanguage = getChosenLanguage;
    _standardLanguage = standardLanguage;
    _sendMessage["Swedish"] = "Skicka meddelande...";
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
