import 'package:flutter/cupertino.dart';

import 'package:yatzy/scroll/animations_scroll.dart';
import 'package:yatzy/top_score/top_score.dart';
import 'package:yatzy/tutorial/tutorial.dart';

import 'application/application.dart';
import 'chat/chat.dart';
import 'dices/dices.dart';
import 'input_items/input_items.dart';
import 'net/net.dart';

var isOnline = false;
var isDebug = true;

// Updated localhost URL to ensure it works with the current network configuration
// In local development, use your actual machine's IP address instead of 192.168.0.168
// This is important for Socket.IO connections to work properly
var localhost = isOnline 
    ? isDebug 
        ? "https://fluttersystems.com" 
        : "https://clientsystem.net" 
    : "http://localhost:8000";

var localhostNET = "https://localhost:44357/api/Values";
var localhostNETIO = "wss://localhost:44357/ws";
var applicationStarted = false;
var userName = "Yatzy";
var userNames = [];
//var devicePixelRatio = 0.0;
var isTesting = false;
var isTutorial = true;
var mainPageLoaded = false;
var keySettings = GlobalKey();
late double screenWidth;
late double screenHeight;
late double devicePixelRatio;

var chosenLanguage = "Swedish";
var standardLanguage = "English";

var differentLanguages = ["English", "Swedish"];

// scrcpy -s R3CR4037M1R --shortcut-mod=lctrl --always-on-top --stay-awake --window-title "Samsung Galaxy S21"
// android:theme="@style/UnityThemeSelector.Translucent"
// android/app/src/main/AndroidManifest.xml

var inputItems = InputItems();
late Tutorial tutorial;
//var languagesGlobal = LanguagesGlobal();

late Net net;
late TopScore topScore;
late AnimationsScroll animationsScroll; // = AnimationsScroll();

late Application app;
late Chat chat;

late Dices dices;
