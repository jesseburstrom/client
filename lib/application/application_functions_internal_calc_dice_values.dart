import 'application.dart';

extension ApplicationCalcDiceValues on Application {
  int zero() {
    return 0;
  }

  int calcOnes() {
    var eye = 1;
    var value = 0;
    for (var i = 0; i < gameDices.nrDices; i++) {
      if (gameDices.diceValue[i] == eye) {
        value += eye;
      }
    }
    return value;
  }

  int calcTwos() {
    var eye = 2;
    var value = 0;
    for (var i = 0; i < gameDices.nrDices; i++) {
      if (gameDices.diceValue[i] == eye) {
        value += eye;
      }
    }
    return value;
  }

  int calcThrees() {
    var eye = 3;
    var value = 0;
    for (var i = 0; i < gameDices.nrDices; i++) {
      if (gameDices.diceValue[i] == eye) {
        value += eye;
      }
    }
    return value;
  }

  int calcFours() {
    var eye = 4;
    var value = 0;
    for (var i = 0; i < gameDices.nrDices; i++) {
      if (gameDices.diceValue[i] == eye) {
        value += eye;
      }
    }
    return value;
  }

  int calcFives() {
    var eye = 5;
    var value = 0;
    for (var i = 0; i < gameDices.nrDices; i++) {
      if (gameDices.diceValue[i] == eye) {
        value += eye;
      }
    }
    return value;
  }

  int calcSixes() {
    var eye = 6;
    var value = 0;
    for (var i = 0; i < gameDices.nrDices; i++) {
      if (gameDices.diceValue[i] == eye) {
        value += eye;
      }
    }
    return value;
  }

  List calcDiceNr() {
    var tmp = List.filled(6, 0);
    for (var i = 0; i < gameDices.nrDices; i++) {
      tmp[gameDices.diceValue[i] - 1]++;
    }
    return tmp;
  }

  int calcPair() {
    var value = 0;
    var diceNr = calcDiceNr();
    for (var i = 5; i >= 0; i--) {
      if (diceNr[i] >= 2) {
        value = (i + 1) * 2;
        break;
      }
    }
    return value;
  }

  int calcTwoPairs() {
    var value = 0;
    var pairs = 0;
    var diceNr = calcDiceNr();
    for (var i = 5; i >= 0; i--) {
      if (diceNr[i] >= 2 && pairs < 2) {
        value += (i + 1) * 2;
        pairs++;
      }
    }
    if (pairs < 2) {
      value = 0;
    }
    return value;
  }

  int calcThreePairs() {
    var value = 0;
    var pairs = 0;
    var diceNr = calcDiceNr();
    for (var i = 5; i >= 0; i--) {
      if (diceNr[i] >= 2) {
        value += (i + 1) * 2;
        pairs++;
      }
    }
    if (pairs != 3) {
      value = 0;
    }
    return value;
  }

  int calcThreeOfKind() {
    var value = 0;
    var diceNr = calcDiceNr();
    for (var i = 5; i >= 0; i--) {
      if (diceNr[i] >= 3) {
        value = (i + 1) * 3;
        break;
      }
    }
    return value;
  }

  int calcFourOfKind() {
    var value = 0;
    var diceNr = calcDiceNr();
    for (var i = 5; i >= 0; i--) {
      if (diceNr[i] >= 4) {
        value = (i + 1) * 4;
        break;
      }
    }
    return value;
  }

  int calcFiveOfKind() {
    var value = 0;
    var diceNr = calcDiceNr();
    for (var i = 5; i >= 0; i--) {
      if (diceNr[i] >= 5) {
        value = (i + 1) * 5;
        break;
      }
    }
    return value;
  }

  int calcYatzy() {
    var value = 0;
    var diceNr = calcDiceNr();
    for (var i = 5; i >= 0; i--) {
      if (diceNr[i] == gameDices.nrDices) {
        if (gameDices.nrDices == 4) {
          value = 25;
        }
        if (gameDices.nrDices == 5) {
          value = 50;
        }
        if (gameDices.nrDices == 6) {
          value = 100;
        }
      }
    }
    return value;
  }

  int calcHouse() {
    var value = 0;
    var pair = 0;
    var triplet = 0;
    var diceNr = calcDiceNr();

    for (var i = 5; i >= 0; i--) {
      if (diceNr[i] >= 3) {
        value += (i + 1) * 3;
        triplet = 1;
        diceNr[i] = 0;
        break;
      }
    }

    for (var i = 5; i >= 0; i--) {
      if (diceNr[i] >= 2) {
        value += (i + 1) * 2;
        pair = 1;
        break;
      }
    }
    if ((pair != 1) || (triplet != 1)) {
      value = 0;
    }
    return value;
  }

  int calcTower() {
    var value = 0;
    var pair = 0;
    var quadruple = 0;

    var diceNr = calcDiceNr();

    for (var i = 5; i >= 0; i--) {
      if (diceNr[i] >= 4) {
        value += (i + 1) * 4;
        quadruple = 1;
        diceNr[i] = 0;
        break;
      }
    }

    for (var i = 5; i >= 0; i--) {
      if (diceNr[i] >= 2) {
        value += (i + 1) * 2;
        pair = 1;
        break;
      }
    }
    if ((pair != 1) || (quadruple != 1)) {
      value = 0;
    }
    return value;
  }

  int calcVilla() {
    var value = 0;
    var threes = 0;
    var diceNr = calcDiceNr();
    for (var i = 5; i >= 0; i--) {
      if (diceNr[i] == 3) {
        value += (i + 1) * 3;
        threes++;
      }
    }
    if (threes != 2) {
      value = 0;
    }
    return value;
  }

  int calcSmallLadder() {
    var value = 0;
    var diceNr = calcDiceNr();
    if (gameType == "Ordinary") {
      // Text is not displayed and therefore not translated
      if ((diceNr[0] > 0) &&
          (diceNr[1] > 0) &&
          (diceNr[2] > 0) &&
          (diceNr[3] > 0) &&
          (diceNr[4] > 0)) {
        value = 1 + 2 + 3 + 4 + 5;
      }
    }
    if (gameType == "Mini") {
      if ((diceNr[0] > 0) &&
          (diceNr[1] > 0) &&
          (diceNr[2] > 0) &&
          (diceNr[3] > 0)) {
        value = 1 + 2 + 3 + 4;
      }
    }
    if (gameType.startsWith("Maxi")) {
      if ((diceNr[0] > 0) &&
          (diceNr[1] > 0) &&
          (diceNr[2] > 0) &&
          (diceNr[3] > 0) &&
          (diceNr[4] > 0)) {
        value = 1 + 2 + 3 + 4 + 5;
      }
    }
    return value;
  }

  int calcLargeLadder() {
    var value = 0;
    var diceNr = calcDiceNr();
    if (gameType == "Ordinary") {
      if ((diceNr[1] > 0) &&
          (diceNr[2] > 0) &&
          (diceNr[3] > 0) &&
          (diceNr[4] > 0) &&
          (diceNr[5] > 0)) {
        value = 2 + 3 + 4 + 5 + 6;
      }
    }
    if (gameType == "Mini") {
      if ((diceNr[2] > 0) &&
          (diceNr[3] > 0) &&
          (diceNr[4] > 0) &&
          (diceNr[5] > 0)) {
        value = 3 + 4 + 5 + 6;
      }
    }
    if (gameType.startsWith("Maxi")) {
      if ((diceNr[1] > 0) &&
          (diceNr[2] > 0) &&
          (diceNr[3] > 0) &&
          (diceNr[4] > 0) &&
          (diceNr[5] > 0)) {
        value = 2 + 3 + 4 + 5 + 6;
      }
    }
    return value;
  }

  int calcMiddleLadder() {
    var value = 0;
    var diceNr = calcDiceNr();
    if (gameType == "Mini") {
      if ((diceNr[1] > 0) &&
          (diceNr[2] > 0) &&
          (diceNr[3] > 0) &&
          (diceNr[4] > 0)) {
        value = 2 + 3 + 4 + 5;
      }
    }
    return value;
  }

  int calcFullLadder() {
    var value = 0;
    var diceNr = calcDiceNr();
    if (gameType.startsWith("Maxi")) {
      if ((diceNr[0] > 0) &&
          (diceNr[1] > 0) &&
          (diceNr[2] > 0) &&
          (diceNr[3] > 0) &&
          (diceNr[4] > 0) &&
          (diceNr[5] > 0)) {
        value = 1 + 2 + 3 + 4 + 5 + 6;
      }
    }
    return value;
  }

  int calcChance() {
    var value = 0;

    for (var i = 0; i < gameDices.nrDices; i++) {
      value += gameDices.diceValue[i];
    }
    return value;
  }
}
