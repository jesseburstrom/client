import 'dart:convert';

import 'package:flutter/animation.dart';
import 'languages_top_score.dart';

class TopScore with LanguagesTopScore {
  final dynamic _net;
  final Function _getChosenLanguage;
  final String _standardLanguage;
  late AnimationController animationController;
  late Animation<double> loopAnimation;
  
  // Track which game types we've already loaded to prevent duplicate requests
  final Map<String, bool> _loadedGameTypes = {};

  TopScore(
      {required Function getChosenLanguage,
      required String standardLanguage,
      required dynamic net})
      : _getChosenLanguage = getChosenLanguage,
        _standardLanguage = standardLanguage,
        _net = net;

  List<dynamic> topScores = [];

  Function getChosenLanguage() {
    return _getChosenLanguage;
  }

  String standardLanguage() {
    return _standardLanguage;
  }

  Future loadTopScoreFromServer(String gameType) async {
    // Check if we've already loaded this game type in this session
    if (_loadedGameTypes[gameType] == true) {
      print('📊 [TopScore] Already loaded $gameType top scores in this session, skipping duplicate request');
      return;
    }
    
    // Set the flag immediately to prevent concurrent duplicate requests
    _loadedGameTypes[gameType] = true;
    
    print('📊 [TopScore] Loading top scores for game type: $gameType');
    try {
      var serverResponse =
          await _net.getDB("/GetTopScores?count=20&type=$gameType");
      if (serverResponse.statusCode == 200) {
        topScores = jsonDecode(serverResponse.body);
        print('📊 [TopScore] Successfully loaded ${topScores.length} scores for $gameType');
      } else {
        // Reset the flag in case of error to allow retrying
        _loadedGameTypes[gameType] = false;
        print('⚠️ [TopScore] Failed to load scores for $gameType: Status ${serverResponse.statusCode}');
      }
    } catch (e) {
      // Reset the flag in case of error to allow retrying
      _loadedGameTypes[gameType] = false;
      print('❌ [TopScore] Error loading top scores: $e');
    }
  }

  Future updateTopScore(String name, int score, String gameType) async {
    print('📊 [TopScore] Updating top score: $name/$score/$gameType');
    try {
      var serverResponse = await _net.postDB("/UpdateTopScore",
          {"name": name, "score": score, "type": gameType, "count": 20});
      if (serverResponse.statusCode == 200) {
        topScores = jsonDecode(serverResponse.body);
        _loadedGameTypes[gameType] = true;
        print('📊 [TopScore] Top scores updated successfully');
      }
    } catch (e) {
      print('❌ [TopScore] Error updating top scores: $e');
    }
  }
}
