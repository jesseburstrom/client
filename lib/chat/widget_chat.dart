import 'package:flutter/material.dart';
import 'package:yatzy/chat/languages_chat.dart';
import '../startup.dart';


class WidgetChat extends StatefulWidget {
  final double width;
  final double height;

  const WidgetChat(
      {super.key, required this.width, required this.height});

  @override
  State<WidgetChat> createState() =>
      _WidgetChatState();
}

class _WidgetChatState extends State<WidgetChat> with LanguagesChat{
  @override
  void initState() {
    super.initState();
    languagesSetup(chat.getChosenLanguage(), chat.standardLanguage());
  }

  @override
  Widget build(BuildContext context) {
    double width = widget.width;
    double height = widget.height;

    Widget widgetInputText(String hintText, Function onSubmitted,
        Function onChanged, TextEditingController controller, FocusNode focusNode,
        [int maxLength = 12]) {
      return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: TextField(
            onChanged: (value) {
              onChanged(value);
            },
            onSubmitted: (value) {
              onSubmitted(value);
            },
            cursorColor: Colors.blue.shade700,
            focusNode: focusNode,
            controller: controller,
            maxLength: maxLength,
            style: const TextStyle(fontSize: 14.0, color: Colors.black87),
            decoration: InputDecoration(
              counterText: "",
              filled: true,
              fillColor: Colors.white.withOpacity(0.9),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.blue.shade700, width: 2.0),
                borderRadius: BorderRadius.circular(25.0),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.blue.shade300, width: 1.0),
                borderRadius: BorderRadius.circular(25.0),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
              hintText: hintText,
              hintStyle: TextStyle(color: Colors.grey.shade600),
              suffixIcon: IconButton(
                icon: Icon(Icons.send, color: Colors.blue.shade700),
                onPressed: () {
                  if (controller.text.isNotEmpty) {
                    onSubmitted(controller.text);
                    controller.clear();
                  }
                },
              ),
            ),
          ));
    }

    Widget widgetChatOutput() {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          // Add a subtle gradient background
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade50.withOpacity(0.6),
              Colors.white.withOpacity(0.2),
            ],
          ),
          // Add a subtle border
          border: Border.all(
            color: Colors.blue.shade200.withOpacity(0.5),
            width: 1.0,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: ListView.builder(
            controller: chat.scrollController,
            itemCount: chat.messages.length,
            shrinkWrap: true,
            padding: const EdgeInsets.only(top: 15, bottom: 10, left: 10, right: 10),
            itemBuilder: (context, index) {
              if (chat.messages[index].messageContent.isNotEmpty) {
                bool isReceiver = chat.messages[index].messageType == "receiver";
                return Container(
                  padding: const EdgeInsets.only(
                      left: 8, right: 8, top: 3, bottom: 3),
                  child: Align(
                    alignment: (isReceiver
                        ? Alignment.centerLeft
                        : Alignment.centerRight),
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: width * 0.75, // Limit message width
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isReceiver ? 0 : 16),
                          bottomRight: Radius.circular(isReceiver ? 16 : 0),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isReceiver 
                              ? [Colors.grey.shade200, Colors.grey.shade300]
                              : [Colors.blue.shade300, Colors.blue.shade400],
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 10),
                      child: Text(
                        chat.messages[index].messageContent,
                        style: TextStyle(
                          fontSize: 14,
                          color: isReceiver ? Colors.black87 : Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              } else {
                return const SizedBox.shrink();
              }
            },
          ),
        ),
      );
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Chat header
            Container(
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blue.shade600,
                    Colors.blue.shade800,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      "Chat",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Chat messages area
            Expanded(
              child: widgetChatOutput(),
            ),
            // Input area
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              child: widgetInputText(
                sendMessage_, 
                (x) => chat.onSubmitted(x, context), 
                (x) => {},
                chat.chatTextController, 
                chat.focusNode, 
                150
              ),
            ),
          ],
        ),
      ),
    );
  }
}
