import 'package:yatzy/top_score/top_score.dart';
import 'application/application.dart';
import 'chat/chat.dart';
import 'dices/dices.dart';
import 'input_items/input_items.dart';

var isOnline = true;

var localhost = isOnline
        ? "https://fluttersystems.com"
    : "http://localhost:8000";

var showUnityOptions = false;
var standardLanguage = "English";
var userNames = [];
var isTesting = false;
var isTutorial = true;
var mainPageLoaded = false;
late double screenWidth;
late double screenHeight;
late double devicePixelRatio;

var differentLanguages = ["English", "Swedish"];

// android:theme="@style/UnityThemeSelector.Translucent"
// android/app/src/main/AndroidManifest.xml

var inputItems = InputItems();

late TopScore topScore;

late Application app;
late Chat chat;

late Dices dices;
