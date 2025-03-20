class UnityMessage {
  UnityMessage(this.actionUnity);

  UnityMessage.reset(this.nrDices, this.nrThrows) {
    actionUnity = "reset";
  }

  UnityMessage.start() {
    actionUnity = "start";
  }

  UnityMessage.updateDices(this.dices) {
    actionUnity = "setProperty";
    property = "Dices";
  }

  UnityMessage.updateColors(this.unityColors) {
    actionUnity = "setProperty";
    property = "Color";
  }

  UnityMessage.changeBool(this.property, this.flag) {
    actionUnity = "setProperty";
  }

  UnityMessage.fromJson(Map<String, dynamic> json)
      : actionUnity = json["actionUnity"],
        nrDices = json["nrDices"],
        nrThrows = json["nrThrows"],
        property = json["property"],
        unityColors = json["colors"],
        flag = json["flag"],
        dices = json["Dices"];

  Map<String, dynamic> toJson() => {
        "actionUnity": actionUnity,
        "nrDices": nrDices,
        "nrThrows": nrThrows,
        "property": property,
        "colors": unityColors,
        "bool": flag,
        "Dices": dices,
      };

  var actionUnity = "";
  var property = "";
  var dices = [];
  var unityColors = [0.6, 0.7, 0.8, 0.1];
  var flag = true;
  var nrDices = 5;
  var nrThrows = 3;
}
