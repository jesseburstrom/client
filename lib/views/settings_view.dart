import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yatzy/application/widget_application_settings.dart';

import '../shared_preferences.dart';
import '../startup.dart';
import '../states/cubit/state/state_cubit.dart';

@RoutePage()
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewHomeState();
}

class _SettingsViewHomeState extends State<SettingsView>
    with TickerProviderStateMixin {
  void myState() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    app.tabController = TabController(length: 2, vsync: this);
    // *** ADD: Load Settings on Init ***
    _loadSettings();
    // *******************************

    // Initialize TextEditingController AFTER loading userName
    app.textEditingController.text = userName; // Use app.userName here
  }

  // Helper function to load settings
  void _loadSettings() async {
    print("⚙️ Loading settings in SettingsView initState...");
    try {
      // Load the combined settings object first
      var settings = await SharedPrefProvider.fetchPrefObject('yatzySettings');
      print("⚙️ Loaded 'yatzySettings' object: $settings");

      if (settings is Map && settings.isNotEmpty) {
        // Update app state from the loaded object
        userName = settings["userName"] ?? userName; // Use ?? default
        app.gameType = settings["gameType"] ?? app.gameType;
        app.nrPlayers = settings["nrPlayers"] ?? app.nrPlayers;
        app.boardAnimation = settings["boardAnimation"] ?? app.boardAnimation;
        // Ensure Dices settings are updated (check for null safety)
        app.gameDices.unityDices = settings["unityDices"] ?? app.gameDices.unityDices;
        app.gameDices.unityLightMotion = settings["unityLightMotion"] ?? app.gameDices.unityLightMotion;
        // Load other unity settings if saved (fun, snow, etc.)
        app.gameDices.unityFun = settings["unityFun"] ?? app.gameDices.unityFun;
        app.gameDices.unitySnowEffect = settings["unitySnowEffect"] ?? app.gameDices.unitySnowEffect;
              // Language is handled by LanguageBloc, but ensure consistency if needed
        chosenLanguage = settings["language"] ?? chosenLanguage;

        print("⚙️ Settings applied: userName=${userName}, gameType=${app.gameType}, nrPlayers=${app.nrPlayers}, unity=${app.gameDices.unityDices}");

      } else {
        print("⚙️ No valid 'yatzySettings' object found. Using defaults or previously loaded values.");
        // Optionally load individual values as fallback if 'yatzySettings' doesn't exist
        // app.userName = SharedPrefProvider.fetchPrefString('userName') ?? app.userName; // Example
      }

      // Ensure the text controller reflects the potentially loaded userName
      app.textEditingController.text = userName;

    } catch (e) {
      print("❌ Error loading settings: $e");
      // Handle error, potentially reset to defaults
    }
    // No setState needed here, as build will use the updated app state
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SetStateCubit, int>(builder: (context, state) {
      return app.widgetScaffoldSettings(context, myState);
    });
  }
}
