using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class DiceScript : MonoBehaviour {

	public int diceNumber;
	public Vector3 originalPosition;
	public Vector3 cupPosition;
	public Vector3 startPosition;
	public bool respondsToClicks;
	public bool isGreen;
	public bool isBlue;
	public bool isActive;
	
	void Awake() {
		originalPosition = transform.position;
		diceNumber = 0;
		respondsToClicks = false;
		isActive = false;
	}
	
	
	void Update () {
		
	}

	void OnMouseDown(){
		if (respondsToClicks) {
			if (isGreen) {
				// Put current dice in storage
				transform.position = originalPosition;
				// Move blue dice to start position
				GameObject go = GameObject.Find(transform.name.Replace('G', 'B'));
				go.transform.position = go.GetComponent<DiceScript>().startPosition;
				// rotate it right
				Vector3 rot = transform.rotation.eulerAngles;
                go.transform.rotation = Quaternion.Euler(rot.x, rot.y, rot.z);	
				go.GetComponent<DiceScript>().isActive = true;			
			} else {
				// Put current dice in storage
				transform.position = originalPosition;
				// Move blue dice to start position
				GameObject go = GameObject.Find(transform.name.Replace('B', 'G'));
				go.transform.position = go.GetComponent<DiceScript>().startPosition;
				// rotate it right
				Vector3 rot = transform.rotation.eulerAngles;
                go.transform.rotation = Quaternion.Euler(rot.x, rot.y, rot.z);
				isActive = false;			
			}
		}
	}

	public int GetDiceNumber() {
		return diceNumber;
	}
	public void SetDiceNumber(int number) {
		diceNumber = number;
	}

}
