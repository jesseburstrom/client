import 'package:flutter/material.dart';

class InputItems {
  Widget widgetImage(double width, double height, String image) {
    return Padding(
      padding: const EdgeInsets.only(top: 10.0),
      child: Center(
        child:
            SizedBox(width: width, height: height, child: Image.asset(image)),
      ),
    );
  }

  Widget widgetInputDBEntry(String hintText, TextEditingController controller) {
    return Padding(
        padding:
            const EdgeInsets.only(left: 5.0, right: 5.0, top: 0, bottom: 0),
        child: TextField(
          cursorColor: Colors.black,
          controller: controller,
          style: const TextStyle(fontSize: 14.0, color: Colors.black),
          decoration: InputDecoration(
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.black, width: 2.0),
            ),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 5.0, horizontal: 5.0),
            border: const OutlineInputBorder(),
            hintText: hintText,
          ),
        ));
  }

  Widget widgetInputText(String hintText, Function onSubmitted,
      Function onChanged, TextEditingController controller, FocusNode focusNode,
      [int maxLength = 12]) {
    return Padding(
        padding:
            const EdgeInsets.only(left: 5.0, right: 5.0, top: 0, bottom: 0),
        child: TextField(
          onChanged: (value) {
            onChanged(value);
          },
          onSubmitted: (value) {
            onSubmitted(value);
          },
          cursorColor: Colors.black,
          focusNode: focusNode,
          controller: controller,
          maxLength: maxLength,
          style: const TextStyle(fontSize: 14.0, color: Colors.black),
          decoration: InputDecoration(
            counterText: "",
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.black, width: 2.0),
              //borderRadius: BorderRadius.circular(25.0),
            ),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 5.0, horizontal: 5.0),
            border: const OutlineInputBorder(),
            hintText: hintText,
          ),
        ));
  }

  // Widget widgetInputEmail(
  //     String labelText, String hintText, TextEditingController controller) {
  //   return Padding(
  //     padding:
  //         const EdgeInsets.only(left: 15.0, right: 15.0, top: 15, bottom: 0),
  //     child: SizedBox(
  //         width: 300,
  //         child: TextFormField(
  //           controller: controller,
  //           keyboardType: TextInputType.text,
  //           decoration: InputDecoration(
  //               border: const OutlineInputBorder(),
  //               labelText: labelText,
  //               hintText: hintText),
  //           validator: (value) {
  //             if (value!.isEmpty) {
  //               return labelText + languagesGlobal.isRequired_;
  //             } else {
  //               return "";
  //             }
  //           },
  //         )),
  //   );
  // }

  // Widget widgetInputPassword(
  //     String labelText, String hintText, TextEditingController controller) {
  //   return Padding(
  //     padding:
  //         const EdgeInsets.only(left: 15.0, right: 15.0, top: 15, bottom: 0),
  //     child: SizedBox(
  //         width: 300,
  //         child: TextFormField(
  //           obscureText: true,
  //           controller: controller,
  //           keyboardType: TextInputType.text,
  //           decoration: InputDecoration(
  //               border: const OutlineInputBorder(),
  //               labelText: labelText,
  //               hintText: hintText),
  //           validator: (value) {
  //             if (value!.isEmpty) {
  //               return labelText + languagesGlobal.isRequired_;
  //             } else {
  //               return "";
  //             }
  //           },
  //         )),
  //   );
  // }

  Widget widgetTextLink(Function onPressed, String text) {
    return TextButton(
      onPressed: () {
        onPressed();
      },
      child: Text(
        text,
        style: const TextStyle(color: Colors.blue, fontSize: 15),
      ),
    );
  }

  // decoration: BoxDecoration(
  // color: Colors.transparent,
  // boxShadow: [
  // BoxShadow(
  // color: Colors.grey.shade600,
  // spreadRadius: 1,
  // blurRadius: 15
  // )
  // ]
  // ),

  Widget widgetButton(Function onPressed, String text) {
    return Container(
      padding: const EdgeInsets.all(8),
      alignment: Alignment.center,
      child: ElevatedButton(
        onPressed: () {
          onPressed();
        },
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.blue.shade700,
          minimumSize: const Size(200, 50),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 6,
          shadowColor: Colors.blue.shade900,
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget widgetSizedBox(double height) {
    return SizedBox(
      height: height,
    );
  }

  Widget widgetIntRadioButton(
      Function state, List<String> values, Function onChanged, int radioValue) {
    Widget radioButton(String name) {
      return Radio(
          value: name,
          groupValue: radioValue.toString(),
          activeColor: Colors.blue.shade700, // Enhanced active color
          fillColor: MaterialStateProperty.resolveWith<Color>((states) {
            if (states.contains(MaterialState.selected)) {
              return Colors.blue.shade700;
            }
            return Colors.grey.shade600; // Better visible inactive color
          }),
          onChanged: (s) {
            onChanged(int.parse(s as String));
            state();
          });
    }

    var radioWidgets = <Widget>[];
    for (var i = 0; i < values.length; i++) {
      radioWidgets.add(radioButton(values[i]));
      radioWidgets.add(
        Text(
          values[i],
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        )
      );
    }
    return Row(
        mainAxisAlignment: MainAxisAlignment.center, children: radioWidgets);
  }

  Widget widgetStringRadioButtonSplit(
      Function state,
      List<String> values,
      List<String> translations,
      Function onChanged,
      String radioValue,
      int splitPoint) {
    Widget radioButton(String name) {
      return Radio(
          value: name,
          groupValue: radioValue,
          activeColor: Colors.blue.shade700, // Enhanced active color
          fillColor: MaterialStateProperty.resolveWith<Color>((states) {
            if (states.contains(MaterialState.selected)) {
              return Colors.blue.shade700;
            }
            return Colors.grey.shade600; // Better visible inactive color
          }),
          onChanged: (s) {
            onChanged(s as String);
            state();
          });
    }

    var radioWidgets1 = <Widget>[];
    var radioWidgets2 = <Widget>[];
    for (var i = 0; i < splitPoint; i++) {
      radioWidgets1.add(radioButton(values[i]));
      radioWidgets1.add(
        Text(
          translations[i],
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        )
      );
    }

    for (var i = splitPoint; i < values.length; i++) {
      radioWidgets2.add(radioButton(values[i]));
      radioWidgets2.add(
        Text(
          translations[i],
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        )
      );
    }

    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center, 
          children: radioWidgets1
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center, 
          children: radioWidgets2
        ),
      ),
    ]);
  }

  Widget widgetStringRadioButton(Function state, List<String> values,
      List<String> translations, Function onChanged, String radioValue) {
    Widget radioButton(String name) {
      return Radio(
          value: name,
          groupValue: radioValue,
          activeColor: Colors.blue.shade700, // Enhanced active color
          fillColor: MaterialStateProperty.resolveWith<Color>((states) {
            if (states.contains(MaterialState.selected)) {
              return Colors.blue.shade700;
            }
            return Colors.grey.shade600; // Better visible inactive color
          }),
          onChanged: (s) {
            onChanged(s as String);
            state();
          });
    }

    var radioWidgets = <Widget>[];
    for (var i = 0; i < values.length; i++) {
      radioWidgets.add(radioButton(values[i]));
      radioWidgets.add(
        Text(
          translations[i],
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        )
      );
    }
    return Row(
        mainAxisAlignment: MainAxisAlignment.center, children: radioWidgets);
  }

  Color getColor(Set<MaterialState> states) {
    const Set<MaterialState> interactiveStates = <MaterialState>{
      MaterialState.pressed,
      MaterialState.hovered,
      MaterialState.focused,
    };
    if (states.any(interactiveStates.contains)) {
      return Colors.blue.shade600;
    }
    return Colors.blue.shade800; // Changed from red to blue for better aesthetics
  }

  Widget widgetCheckbox(
      Function onChanged, String text, bool toggles) {
    List<Widget> checkWidgets = [];

    checkWidgets.add(SizedBox(
        height: 24, // Increased height for better touch target
        width: 24, // Added width for better proportions
        child: Checkbox(
            checkColor: Colors.white,
            fillColor: MaterialStateProperty.resolveWith(getColor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4), // Slightly rounded corners
            ),
            value: toggles,
            onChanged: (bool? value) {
              onChanged(value);
            })));
    checkWidgets.add(Padding(
      padding: const EdgeInsets.only(left: 8.0), // Added padding for text
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          color: Colors.black87, // Better contrast than default
        ),
      ),
    ));
    return Row(
      children: checkWidgets,
      crossAxisAlignment: CrossAxisAlignment.center, // Better vertical alignment
    );
  }

  Widget widgetSlider(BuildContext context, Function state, String text,
      Function onChanged, double slider) {
    var sliderWidgets = <Widget>[];

    sliderWidgets.add(SliderTheme(
        data: SliderTheme.of(context).copyWith(
          activeTrackColor: Colors.blue,
          inactiveTrackColor: Colors.blue,
          trackShape: const RectangularSliderTrackShape(),
          trackHeight: 2.0,
          thumbColor: Colors.blueAccent,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.0),
          overlayColor: Colors.red.withAlpha(32),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 10.0),
        ),
        child: SizedBox(
            //width: 150,
            height: 15,
            child: Slider(
              value: slider,
              onChanged: (value) {
                onChanged(value);
                state();
              },
            ))));
    sliderWidgets.add(Text(text));
    return Row(children: sliderWidgets);
  }

  Widget widgetDropDownList(Function state, String text, List<String> items,
      Function onChanged, String choice) {
    var dropWidgets = <Widget>[];

    dropWidgets.add(Padding(
        padding: const EdgeInsets.all(4.0),
        child: SizedBox(
            width: 150,
            child: DropdownButtonFormField<String>(
              value: choice,
              style: const TextStyle(color: Colors.black87, fontSize: 16),
              focusColor: Colors.white,
              dropdownColor: Colors.white, // Added dropdown menu color
              decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(width: 2, color: Colors.blue.shade600),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(width: 2, color: Colors.blue.shade700),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50, // Background fill for better visibility
              ),
              icon: Icon(Icons.arrow_drop_down, color: Colors.blue.shade700), // Custom dropdown icon
              onChanged: (String? value) {
                onChanged(value);
                state();
              },
              items: items
                  .map((item) => DropdownMenuItem<String>(
                      value: item,
                      child: Text(item, style: const TextStyle(fontSize: 16))))
                  .toList(),
            ))));
    dropWidgets.add(Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Text(
        text, 
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)
      )
    ));
    return Row(children: dropWidgets);
  }

  Widget widgetParagraph(String text) {
    var paragraphWidgets = <Widget>[];
    paragraphWidgets.add(Text(
      text,
      style: TextStyle(
        color: Colors.blue.shade900,
        fontSize: 20, 
        fontWeight: FontWeight.bold,
        fontStyle: FontStyle.italic
      )
    ));
    paragraphWidgets.add(Divider(
      height: 20,
      thickness: 2,
      indent: 0,
      endIndent: 50,
      color: Colors.blue.shade200, // Added color to divider
    ));
    return Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: paragraphWidgets);
  }
}
