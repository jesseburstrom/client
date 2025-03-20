import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Interacts with shared preferences to store and retrieve data
abstract class SharedPrefProvider {
  static late final SharedPreferences prefs;

  static loadPrefs() async {
    prefs = await SharedPreferences.getInstance();
  }

  /// Static lambda functions to retrieve value from state objects
  static bool fetchPrefBool(String key) => prefs.getBool(key) ?? false;

  static int fetchPrefInt(String key) => prefs.getInt(key) ?? 0;

  static String fetchPrefString(String key) => prefs.getString(key) ?? '';

  static dynamic fetchPrefObject(String key) =>
      jsonDecode(prefs.getString(key) ?? jsonEncode({}));

  /// Static lambda functions to set value from state objects
  static Future<bool> setPrefBool(String key, bool value) async {
    return await prefs.setBool(key, value);
  }

  static Future<bool> setPrefInt(String key, int value) async {
    return await prefs.setInt(key, value);
  }

  static Future<bool> setPrefString(String key, String value) async {
    return await prefs.setString(key, value);
  }

  static Future<bool> setPrefObject(String key, value) async {
    return await prefs.setString(key, jsonEncode(value));
  }
}
