using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ThrowDices : MonoBehaviour
{
    GameObject gameManager;
    // Start is called before the first frame update
    void Awake()
    {
        gameManager = GameObject.Find("GameManager");
    }
    void OnMouseDown(){
        Debug.Log("MouseDown");
            
        if (gameManager.GetComponent<GameManagerScript>().throwActive) {
            gameManager.GetComponent<GameManagerScript>().throwDices = true;
        }
    }
    // Update is called once per frame
    void Update()
    {
        
    }
}
