using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class CircularMotionScript : MonoBehaviour
{
    float timeCounter=0;
    public Color myColor;
    public bool lightMotion;
    Vector3 originalPosition;
    private float speed;
    // Start is called before the first frame update
    void Start()
    {
        speed = 10f;
        originalPosition = transform.position;
        lightMotion = true;
        myColor = new Color(0.15f, 0.10f, 0.0f, 0f);
        // goStartPlane = new GameObject();  
        // goPlane = new GameObject();  
        // goWall1 = new GameObject();  
        // goWall2 = new GameObject();  
        // goStartPlane = GameObject.Find("StartPlane");
        // goPlane = GameObject.Find("Plane");
        // goWall1 = GameObject.Find("Wall1");
        // goWall2 = GameObject.Find("Wall2");
        // meshRendererStartPlane = new MeshRenderer();
        // meshRendererPlane = new MeshRenderer();
        // meshRendererWall1 = new MeshRenderer();
        // meshRendererWall2 = new MeshRenderer();
        // meshRendererStartPlane = goStartPlane.GetComponent<MeshRenderer>();
        // meshRendererPlane = goPlane.GetComponent<MeshRenderer>();
        // meshRendererWall1 = goWall1.GetComponent<MeshRenderer>();
        // meshRendererWall2 = goWall3.GetComponent<MeshRenderer>();

    }

    // Update is called once per frame
    void Update()
    {
        if (lightMotion) {
            timeCounter += Time.deltaTime;

            float x = speed * Mathf.Cos(timeCounter) + originalPosition.x;
            float y = transform.position.y;
            float z = speed * Mathf.Sin(timeCounter) + originalPosition.z;

            transform.position  = new Vector3(x, y, z);
        }

        GameObject.Find("StartPlane").GetComponent<Renderer>().material.color = myColor;
        //GameObject.Find("Wall1").GetComponent<Renderer>().material.color = myColor;
        //GameObject.Find("Wall2").GetComponent<Renderer>().material.color = myColor;
        GameObject.Find("Plane").GetComponent<Renderer>().material.color = myColor;
        // meshRendererStartPlane.material.color = myColor;
        // meshRendererPlane.material.color = myColor;
        // meshRendererWall1.material.color = myColor;
        // meshRendererWall2.material.color = myColor;
    }
}
