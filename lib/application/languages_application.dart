mixin LanguagesApplication  {

  late Function _getChosenLanguage;
  late String _standardLanguage;

  final _ones = {"English": "Ones"};
  final _twos = {"English": "Twos"};
  final _threes = {"English": "Threes"};
  final _fours = {"English": "Fours"};
  final _fives = {"English": "Fives"};
  final _sixes = {"English": "Sixes"};
  final _sum = {"English": "Sum"};
  final _bonus = {"English": "Bonus"};
  final _pair = {"English": "Pair"};
  final _twoPairs = {"English": "Two Pairs"};
  final _threePairs = {"English": "Three Pairs"};
  final _threeOfKind = {"English": "Three of Kind"};
  final _fourOfKind = {"English": "Four of Kind"};
  final _fiveOfKind = {"English": "Five of Kind"};
  final _house = {"English": "House"};
  final _smallStraight = {"English": "Small Ladder"};
  final _largeStraight = {"English": "Large Ladder"};
  final _fullStraight = {"English": "Full Straight"};
  final _middleStraight = {"English": "Middle Ladder"};
  final _house32 = {"English": "House 3+2"};
  final _house33 = {"English": "House 3+3"};
  final _house24 = {"English": "House 2+4"};
  final _chance = {"English": "Chance"};
  final _yatzy = {"English": "Yatzy"};
  final _maxiYatzy = {"English": "Maxi Yatzy"};
  final _totalSum = {"English": "Total Sum"};
  final _turn = {"English": "turn..."};
  final _your = {"English": "Your"};
  final _gameFinished = {
    "English": "Game Finished, Press Settings Button To Join New Game!"
  };
  final _pressSettingsButton = {"English": "Press Settings Button"};
  final _toJoinNewGame = {"English": "To Join New Game!"};
  final _chooseMove = {"English": "\nChoose Move"};
  final _pressSettings = {"English": "Press Settings\nButton"};
  final _restart = {"English": "Restart"};
  final _regretsLeft = {"English": "Regrets Left"};
  final _extraMovesLeft = {"English": "Extra Moves Left"};

  // Settings

  final _gameTypeOrdinary = {"English": "Ordinary"};
  final _gameTypeMini = {"English": "Mini"};
  final _gameTypeMaxi = {"English": "Maxi"};
  final _gameTypeMaxiR3 = {"English": "Maxi Regret 3"};
  final _gameTypeMaxiE3 = {"English": "Maxi Extra 3"};
  final _gameTypeMaxiRE3 = {"English": "Maxi Regret Extra 3"};
  final _settings = {"English": "Settings"};
  final _game = {"English": "Game"};
  final _general = {"English": "General"};
  final _choseLanguage = {"English": "Chose Language"};
  final _startGame = {"English": "Start Game"};
  final _createGame = {"English": "Create Game"};
  final _transparency = {"English": "Transparency"};
  final _lightMotion = {"English": "Light Motion"};
  final _red = {"English": "Red"};
  final _green = {"English": "Green"};
  final _blue = {"English": "Blue"};
  final _appearance = {"English": "Appearance"};
  final _misc = {"English": "Misc"};
  final _gameRequest = {"English": "Game Request"};
  final _currentUsername = {"English": "Current username: "};
  final _enterUsername = {"English": "Enter username"};
  final _ongoingGames = {"English": "Ongoing Games"};
  final _boardAnimation = {"English": "Board Animation"};
  final _useTutorial = {"English": "Use Tutorial"};

  String get ones_ => getText(_ones);

  String get twos_ => getText(_twos);

  String get threes_ => getText(_threes);

  String get fours_ => getText(_fours);

  String get fives_ => getText(_fives);

  String get sixes_ => getText(_sixes);

  String get sum_ => getText(_sum);

  String get bonus_ => getText(_bonus);

  String get pair_ => getText(_pair);

  String get twoPairs_ => getText(_twoPairs);

  String get threePairs_ => getText(_threePairs);

  String get threeOfKind_ => getText(_threeOfKind);

  String get fourOfKind_ => getText(_fourOfKind);

  String get fiveOfKind_ => getText(_fiveOfKind);

  String get house_ => getText(_house);

  String get smallStraight_ => getText(_smallStraight);

  String get largeStraight_ => getText(_largeStraight);

  String get fullStraight_ => getText(_fullStraight);

  String get middleStraight_ => getText(_middleStraight);

  String get house32_ => getText(_house32);

  String get house33_ => getText(_house33);

  String get house24_ => getText(_house24);

  String get chance_ => getText(_chance);

  String get yatzy_ => getText(_yatzy);

  String get maxiYatzy_ => getText(_maxiYatzy);

  String get totalSum_ => getText(_totalSum);

  String get turn_ => getText(_turn);

  String get your_ => getText(_your);

  String get gameFinished_ => getText(_gameFinished);

  String get pressSettingsButton_ => getText(_pressSettingsButton);

  String get toJoinNewGame_ => getText(_toJoinNewGame);

  String get chooseMove_ => getText(_chooseMove);

  String get pressSettings_ => getText(_pressSettings);

  String get restart_ => getText(_restart);

  String get regretsLeft_ => getText(_regretsLeft);

  String get extraMovesLeft_ => getText(_extraMovesLeft);

  // Settings

  String get gameTypeOrdinary_ => getText(_gameTypeOrdinary);

  String get gameTypeMini_ => getText(_gameTypeMini);

  String get gameTypeMaxi_ => getText(_gameTypeMaxi);

  String get gameTypeMaxiR3_ => getText(_gameTypeMaxiR3);

  String get gameTypeMaxiE3_ => getText(_gameTypeMaxiE3);

  String get gameTypeMaxiRE3_ => getText(_gameTypeMaxiRE3);

  String get settings_ => getText(_settings);

  String get game_ => getText(_game);

  String get general_ => getText(_general);

  String get choseLanguage_ => getText(_choseLanguage);

  String get startGame_ => getText(_startGame);

  String get createGame_ => getText(_createGame);

  String get transparency_ => getText(_transparency);

  String get lightMotion_ => getText(_lightMotion);

  String get red_ => getText(_red);

  String get green_ => getText(_green);

  String get blue_ => getText(_blue);

  String get appearance_ => getText(_appearance);

  String get misc_ => getText(_misc);

  String get gameRequest_ => getText(_gameRequest);

  String get currentUsername_ => getText(_currentUsername);

  String get enterUsername_ => getText(_enterUsername);

  String get ongoingGames_ => getText(_ongoingGames);

  String get boardAnimation_ => getText(_boardAnimation);

  String get useTutorial_ => getText(_useTutorial);


  void languagesSetup(Function getChosenLanguage, String standardLanguage) {
    _getChosenLanguage = getChosenLanguage;
    _standardLanguage = standardLanguage;
    _ones["Swedish"] = "Ettor";
    _twos["Swedish"] = "Tvåor";
    _threes["Swedish"] = "Treor";
    _fours["Swedish"] = "Fyror";
    _fives["Swedish"] = "Femmor";
    _sixes["Swedish"] = "Sexor";
    _sum["Swedish"] = "Summa";
    _bonus["Swedish"] = "Bonus";
    _pair["Swedish"] = "Par";
    _twoPairs["Swedish"] = "Två Par";
    _threePairs["Swedish"] = "Tre Par";
    _threeOfKind["Swedish"] = "Triss";
    _fourOfKind["Swedish"] = "Fyrtal";
    _fiveOfKind["Swedish"] = "Femtal";
    _house["Swedish"] = "Kåk";
    _smallStraight["Swedish"] = "Liten Stege";
    _largeStraight["Swedish"] = "Stor Stege";
    _fullStraight["Swedish"] = "Hel Stege";
    _middleStraight["Swedish"] = "Mellan Stege";
    _house32["Swedish"] = "Kåk 3+2";
    _house33["Swedish"] = "Hus 3+3";
    _house24["Swedish"] = "Torn 2+4";
    _chance["Swedish"] = "Chans";
    _yatzy["Swedish"] = "Yatzy";
    _maxiYatzy["Swedish"] = "Maxi Yatzy";
    _totalSum["Swedish"] = "Total Summa";
    _turn["Swedish"] = "tur...";
    _your["Swedish"] = "Din";
    _gameFinished["Swedish"] =
        "Spelet Är Slut, Tryck På Inställningar Knappen För Att Starta Nytt Spel!";
    //_gameFinished["Swedish"] = "Spelet Är Slut,";
    _pressSettingsButton["Swedish"] = "Tryck På Inställningar Knappen";
    _toJoinNewGame["Swedish"] = "För Att Starta Nytt Spel!";
    _chooseMove["Swedish"] = "\nVälj Drag";
    _pressSettings["Swedish"] = "Gå Till \ninställningar";
    _restart["Swedish"] = "Starta Om";
    _regretsLeft["Swedish"] = "Ångra Kvar";
    _extraMovesLeft["Swedish"] = "Extra Kast Kvar";

    // Settings

    _gameTypeOrdinary["Swedish"] = "Standard";
    _settings["Swedish"] = "Inställningar";
    _game["Swedish"] = "Spel";
    _general["Swedish"] = "Allmänt";
    _choseLanguage["Swedish"] = "Välj Språk";
    _startGame["Swedish"] = "Starta Spelet";
    _createGame["Swedish"] = "Skapa Spel";
    _transparency["Swedish"] = "Transparens";
    _lightMotion["Swedish"] = "Cirkulärt Ljus";
    _red["Swedish"] = "Röd";
    _green["Swedish"] = "Grön";
    _blue["Swedish"] = "Blå";
    _appearance["Swedish"] = "Utseende";
    _misc["Swedish"] = "Diverse";
    _gameRequest["Swedish"] = "Spel Inbjudan";
    _currentUsername["Swedish"] = "Nuvarande användarnamn: ";
    _enterUsername["Swedish"] = "Ange användarnamn";
    _ongoingGames["Swedish"] = "Pågående Spel";
    _boardAnimation["Swedish"] = "Spelplans Animation";
    _useTutorial["Swedish"] = "Användar Hjälp På";
    _gameTypeMaxiR3["Swedish"] = "Maxi Ångra 3";
    _gameTypeMaxiRE3["Swedish"] = "Maxi Ångra Extra 3";
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
