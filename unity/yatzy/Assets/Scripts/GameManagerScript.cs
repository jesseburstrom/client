using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using FlutterUnityIntegration;
using Random=UnityEngine.Random;

public class GameManagerScript : MonoBehaviour 
{

    public class jsonCommunicator{
        public string actionUnity;
        public List<int> diceResult;

        public jsonCommunicator(string _actionUnity, List<int> _diceResult) {
            actionUnity = _actionUnity;
            diceResult = new List<int>(_diceResult);
        }
    }

    
    //UnityMessageManager unityMessageManager;
    
    public bool throwDices = false;
    public bool throwActive;

    private static int maxNrDices = 10;
    GameObject []go;
    GameObject []goG;
    GameObject []goB;
    GameObject goSnow;
    bool goSnowActive = false;
    private static List<int> diceResult;
    //private static int []diceResult;
    static Rigidbody rb;
    
    private float c;
    private int nrDices = 5;
    private int nrThrows = 3;
    private int nrThrowsRemaining = 3;
    private Animator animatorCup;
    private Animator animatorCat;
    private Animator animatorDog;
    private float timeFromThrownDices;
    private bool rethrow = false;
    private bool dicesActive = false;
   
    void Start()
    {
        Debug.Log(SystemInfo.graphicsDeviceType);
        gameObject.AddComponent<UnityMessageManager>();
        throwActive = true;
        goSnow = new GameObject();
        goSnow = GameObject.Find("Snow");
        for(int i = 0; i < goSnow.transform.childCount; i++)
        {
            GameObject Go = goSnow.transform.GetChild(i).gameObject;
            Debug.Log(Go.GetComponent<ParticleSystem>().main.startSize.constant);
        }
        goSnow.SetActive(false);
        Time.timeScale = 2f;
        //unityMessageManager = GetComponent<UnityMessageManager>();
        go = new GameObject[maxNrDices];
        goG = new GameObject[maxNrDices];
        goB = new GameObject[maxNrDices];
        diceResult = new List<int>(new int[maxNrDices]);
        
        go[0] = GameObject.Find("Dice1");
        goG[0] = GameObject.Find("DiceG1");
        goB[0] = GameObject.Find("DiceB1");
        for (int i=1; i<maxNrDices; i++) {
            go[i] = GameObject.Find("Dice"+(i+1).ToString());
            goG[i] = GameObject.Find("DiceG"+(i+1).ToString());
            goB[i] = GameObject.Find("DiceB"+(i+1).ToString());
        }

        InitDices();

        float sep = 1.1f;
        float height = 2f;
        go[0].GetComponent<DiceScript>().cupPosition = new Vector3(0,1+height,0);
        go[1].GetComponent<DiceScript>().cupPosition = new Vector3(sep,1+height,0);
        go[2].GetComponent<DiceScript>().cupPosition = new Vector3(-sep,1+height,0);
        go[3].GetComponent<DiceScript>().cupPosition = new Vector3(0,1+height,sep);
        go[4].GetComponent<DiceScript>().cupPosition = new Vector3(0,1+height,-sep);
        go[5].GetComponent<DiceScript>().cupPosition = new Vector3(sep,2+height,sep);
        go[6].GetComponent<DiceScript>().cupPosition = new Vector3(-sep,2+height,sep);
        go[7].GetComponent<DiceScript>().cupPosition = new Vector3(sep,2+height,-sep);
        go[8].GetComponent<DiceScript>().cupPosition = new Vector3(-sep,2+height,-sep);
        go[9].GetComponent<DiceScript>().cupPosition = new Vector3(0,4+height,0);

        // anim = GameObject.Find("Empire_Cup").GetComponent<Animator>();
        animatorCup = GameObject.Find("Empire_Cup").GetComponent<Animator>();
        animatorCup.speed = 1f;
        animatorCat = GameObject.Find("cat_Walk").GetComponent<Animator>();
        animatorCat.Play("Walk");
        animatorDog = GameObject.Find("DogPBR").GetComponent<Animator>();
        animatorDog.Play("Attack01");
        Physics.gravity = new Vector3(0, -20f, 0);
    }

    void InitDices(bool initRotation = true) {

        // Reset all positions first
        for (int i=0; i<maxNrDices; i++) {
            go[i].transform.position = go[i].GetComponent<DiceScript>().originalPosition;
            goG[i].transform.position = goG[i].GetComponent<DiceScript>().originalPosition;
            goB[i].transform.position = goB[i].GetComponent<DiceScript>().originalPosition;
        }

        float c = (20f - nrDices) / (nrDices + 1f);
        go[0].transform.position = new Vector3(GameObject.Find("StartPlane").transform.position.x, 
                                                GameObject.Find("StartPlane").transform.position.y+2.5f, 
                                                GameObject.Find("StartPlane").transform.position.z+c+0.5f-10f);
        if (initRotation){
            go[0].transform.rotation = Quaternion.Euler(0f, 90f, 0f);
        }                                        
        
        go[0].GetComponent<DiceScript>().startPosition = go[0].transform.position;
        goG[0].GetComponent<DiceScript>().startPosition = go[0].transform.position;
        goB[0].GetComponent<DiceScript>().startPosition = go[0].transform.position;
        goB[0].GetComponent<DiceScript>().isActive = false;
        
        for (int i=1; i<nrDices; i++) {
            go[i].transform.position = new Vector3(go[i-1].transform.position.x, go[i-1].transform.position.y, go[i-1].transform.position.z + 1 + c );
            if (initRotation){
                go[i].transform.rotation = Quaternion.Euler(0f, 90f, 0f);
            }
            go[i].GetComponent<DiceScript>().startPosition = go[i].transform.position;
            goG[i].GetComponent<DiceScript>().startPosition = go[i].transform.position;
            goB[i].GetComponent<DiceScript>().startPosition = go[i].transform.position;
            goB[i].GetComponent<DiceScript>().isActive = false;
        }

        for (int i=0; i<nrDices; i++) {
            diceResult[i] = 0; 
        }
    }

    void SetDices(List<int> dices) {
        for(var i=0;i<dices.Count;i++) {
            go[i].transform.rotation = Quaternion.Euler(0f, 90f, 0f);
            switch (dices[i]) {
                case 1:
                    go[i].transform.rotation = Quaternion.Euler(90f, 90f, 0f);
                    break;
                case 2:
                    go[i].transform.rotation = Quaternion.Euler(0f, 90f, 270f);
                    break;
                case 4:
                    go[i].transform.rotation = Quaternion.Euler(180f, 90f, 0f);
                    break;
                case 5:
                    go[i].transform.rotation = Quaternion.Euler(0f, 90f, 90f);
                    break;
                case 6:
                    go[i].transform.rotation = Quaternion.Euler(270f, 90f, 0f);
                    break;
            }
        }
    }
    
    void Update()
    {

        bool isFinished = true;
        for (int i=0; i<nrDices; i++) {
            diceResult[i] = go[i].GetComponent<DiceScript>().GetDiceNumber();
            isFinished = isFinished && diceResult[i] != 0;
        }

        if (isFinished && dicesActive && !rethrow) {
            dicesActive = false;
            for (int i=0; i<nrDices; i++) {
                // Position green dices on start bar if not HOLD i.e blue dice there
                if (!goB[i].GetComponent<DiceScript>().isActive) {
                    //rb = goB[i].GetComponent<Rigidbody>();
                    //rb.angularVelocity = new Vector3(0, 0, 0);
                    goG[i].transform.position = goG[i].GetComponent<DiceScript>().startPosition;
                    Vector3 rot = go[i].GetComponentInParent<Rigidbody>().rotation.eulerAngles;
                    goG[i].transform.rotation = Quaternion.Euler(rot.x, 90f, rot.z);
                    goG[i].GetComponent<DiceScript>().respondsToClicks = true;
                    goB[i].GetComponent<DiceScript>().respondsToClicks = true;
                } 
            }
            var json = new jsonCommunicator("results", diceResult.GetRange(0,nrDices));

            string jsonStr = JsonConvert.SerializeObject(json).ToString();
            nrThrowsRemaining -= 1;
            if (nrThrowsRemaining == 0) {
                InitDices(false);  
                throwActive = false;                      
            }
            UnityMessageManager.Instance.SendMessageToFlutter(jsonStr); 
        }

       
        // Put Dices in Cup
        if ((Time.time - timeFromThrownDices > 7f) && dicesActive || (throwDices && nrThrowsRemaining > 0) || Input.GetKeyDown (KeyCode.O)) {
           Debug.Log(Time.time - timeFromThrownDices);
            dicesActive = true;
            throwDices = false;
            for (int i = 0; i < nrDices; i++) {
                // Check to see which blue dice is on start block HOLD them i.e put corresponding red in storage
                // If not blue put green dice in storage and red in cup
                if (goB[i].GetComponent<DiceScript>().isActive) {
                    go[i].transform.position = go[i].GetComponent<DiceScript>().originalPosition;
                } else {
                    goG[i].transform.position = goG[i].GetComponent<DiceScript>().originalPosition;
                    go[i].transform.position = go[i].GetComponent<DiceScript>().cupPosition + GameObject.Find("Empire_Cup").transform.position;
                    go[i].transform.rotation = Quaternion.identity;
                    rb = go[i].GetComponent<Rigidbody>();
                    rb.angularVelocity = new Vector3(Random.Range (50, 80), Random.Range (50, 80), Random.Range (50, 80));
                    go[i].GetComponent<DiceScript>().SetDiceNumber(0);
                    diceResult[i] = 0;
                }
            }
            
            animatorCup.Play("move");
            timeFromThrownDices = Time.time;
            rethrow = false;
        }
    }

    public void SetNrDices(string strNrDices) {
        nrDices = int.Parse(strNrDices);
        InitDices();
    }
    public void flutterMessage(String json) {
        GameObject localGameObject = new GameObject();
        Debug.Log(json);
        JObject o = JObject.Parse(json);
        Debug.Log(o);
        string action = (string)o["actionUnity"];
        if (action == "unityIdentifier") {
            UnityMessageManager.Instance.SendMessageToFlutter(json);
        } else if (action == "throwDices") {
            throwDices = true;
        } else if (action == "start") {
            Debug.Log("start");
            throwActive = true;
        } else if (action == "reset") {
            nrDices = (int)o["nrDices"];
            nrThrows = (int)o["nrThrows"];
            nrThrowsRemaining = nrThrows;
            InitDices();
            throwActive = false;
        } else if (action == "setProperty") {
            string property = (string)o["property"];
            
            localGameObject = GameObject.Find("CircleLight");
            switch(property){
                case "Color":
                    localGameObject.GetComponent<CircularMotionScript>().myColor = new Color((float)o["colors"][0], (float)o["colors"][1], (float)o["colors"][2], (float)o["colors"][3]);
                break;
                case "Transparency":
                    //localGameObject.GetComponent<CircularMotionScript>().transparentMode = (bool)o["bool"];
                    Debug.Log((bool)o["bool"]);
                    //Debug.Log(localGameObject.GetComponent<CircularMotionScript>().transparentMode);
                break;
                case "LightMotion":
                    localGameObject.GetComponent<CircularMotionScript>().lightMotion = (bool)o["bool"];
                    Debug.Log((bool)o["bool"]);
                    Debug.Log(localGameObject.GetComponent<CircularMotionScript>().lightMotion);
                break;
                case "Dices":
                    InitDices();
                    var temp = (JArray)o["Dices"];
                    Debug.Log(temp);
                    List<int> gotDices = new List<int>(new int[temp.Count]);
                    
                    for(var i=0;i<temp.Count;i++){
                        gotDices[i] = (int)o["Dices"][i];
                    }
                    Debug.Log(gotDices);
                    SetDices(gotDices);
                    break;
                case "SnowEffect":
                    
                    goSnowActive = (bool)o["bool"];
                    goSnow.SetActive(goSnowActive);
                    break;

            }
           
        }
      
    }

   }
