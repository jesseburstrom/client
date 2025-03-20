import 'package:flutter/cupertino.dart';

import '../input_items/input_items.dart';


class ChatMessage {
  ChatMessage(this.messageContent, this.messageType);

  var messageContent = "";
  var messageType = "";
}

class Chat {
  final Function _getChosenLanguage;
  final String _standardLanguage;

  Chat(
      {required Function getChosenLanguage,
      required String standardLanguage,
      required Function callback,
      required this.setState,
      required this.inputItems}) : _getChosenLanguage = getChosenLanguage,
        _standardLanguage = standardLanguage {

    callbackOnSubmitted = callback;
  }

  Function getChosenLanguage() {
    return _getChosenLanguage;
  }

  String standardLanguage() {
    return _standardLanguage;
  }

  final Function setState;
  final InputItems inputItems;
  late Function callbackOnSubmitted;
  final chatTextController = TextEditingController();
  final scrollController = ScrollController();
  var focusNode = FocusNode();
  var listenerKey = GlobalKey();

  // To get the slide in chat-bubble from bottom effect, 15 is for 4k full screen.
  // Otherwise chat starts from top and goes down. Maybe is some other way to start from bottom.
  List<ChatMessage> messages =
      List<ChatMessage>.generate(15, (index) => ChatMessage("", "Sender"));

  onSubmitted(String value, BuildContext context) async {
    var text = chatTextController.text;
    chatTextController.clear();
    messages.add(ChatMessage(text, "sender"));
    callbackOnSubmitted(text);

    setState();

    await Future.delayed(const Duration(milliseconds: 100), () {});
    scrollController.animateTo(scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.fastOutSlowIn);
  }
}
