using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class DiceCheckZoneScript : MonoBehaviour {

	private Vector3 vel;
	private Vector3 angVel;

	void OnTriggerStay(Collider col)
	{
		if (col.gameObject.GetComponentInParent<DiceScript>().GetDiceNumber() == 0) {
			vel = col.gameObject.GetComponentInParent<Rigidbody>().linearVelocity;
			angVel = col.gameObject.GetComponentInParent<Rigidbody>().angularVelocity;
			//if (vel.x < 1e-7f && vel.y < 1e-7f && vel.z < 1e-7f && angVel.x < 1e-7f && angVel.y < 1e-7f && angVel.z < 1e-7f)
			if (vel.x == 0f && vel.y == 0f && vel.z == 0f && angVel.x == 0f && angVel.y == 0f && angVel.z == 0f)
			{
				// Check to see rotation in plane direction is multiple of 90 degrees i.e. lies flat.
				Vector3 rot = col.gameObject.GetComponentInParent<Rigidbody>().rotation.eulerAngles;
				
				// Allow up to 25degree deviation it's still clear which side is top, also check for the negative version of angles :)
					if (Mathf.Abs(rot.x % 90.0f) < 35.0f && Mathf.Abs(rot.z % 90.0f) < 35.0f ||
					Mathf.Abs(90f-rot.x % 90.0f) < 35.0f && Mathf.Abs(rot.z % 90.0f) < 35.0f ||
					Mathf.Abs(rot.x % 90.0f) < 35.0f && Mathf.Abs(90f-rot.z % 90.0f) < 35.0f ||
					Mathf.Abs(90f-rot.x % 90.0f) < 35.0f && Mathf.Abs(90f-rot.z % 90.0f) < 35.0f) {
					switch (col.gameObject.name) {
					case "Side1":

						col.gameObject.GetComponentInParent<DiceScript>().SetDiceNumber(6);
						break;
					case "Side2":
						col.gameObject.GetComponentInParent<DiceScript>().SetDiceNumber(5);
						break;
					case "Side3":
						col.gameObject.GetComponentInParent<DiceScript>().SetDiceNumber(4);
						break;
					case "Side4":
						col.gameObject.GetComponentInParent<DiceScript>().SetDiceNumber(3);
						break;
					case "Side5":
						col.gameObject.GetComponentInParent<DiceScript>().SetDiceNumber(2);
						break;
					case "Side6":
						col.gameObject.GetComponentInParent<DiceScript>().SetDiceNumber(1);
						break;
					} 
				} else {
					// Debug.Log("Failed Throw!!!!!!!!!!!!!!!!!!!!!!!");
					// Debug.Log("rot.x: " + rot.x.ToString() + " rot.y: " + rot.y.ToString() + " rot.z: " + rot.z.ToString());
					// Debug.Log(col.gameObject.name);
				}
			}			
		}
	}
}
