using System;
using System.Collections;
using System.Collections.Concurrent;
using System.Collections.Generic;
using UnityEngine;

using NativeWebSocket;

public class Connection : MonoBehaviour
{
  WebSocket websocket;
  private readonly ConcurrentQueue<Action> _actions = new ConcurrentQueue<Action>(); 
  bool isOnline = false;
  // Start is called before the first frame update
  async void Start()
  {
    // websocket = new WebSocket("ws://echo.websocket.org");
    websocket = isOnline ? new WebSocket("wss://clientsystem.net/ws") : new WebSocket("ws://localhost:8001");

    websocket.OnOpen += () =>
    {
      Debug.Log("Connection open!");
    };

    websocket.OnError += (e) =>
    {
      Debug.Log("Error! " + e);
    };

    websocket.OnClose += (e) =>
    {
      Debug.Log("Connection closed!");
    };

    websocket.OnMessage += (bytes) =>
    {
      // Reading a plain text message
      var message = System.Text.Encoding.UTF8.GetString(bytes);
      Debug.Log("Received OnMessage! (" + bytes.Length + " bytes) " + message);
      _actions.Enqueue(() => GameObject.Find("GameManager").GetComponent<GameManagerScript>().flutterMessage(message));
    };

    // Keep sending messages at every 0.3s
    //InvokeRepeating("SendWebSocketMessage", 0.0f, 0.3f);

    await websocket.Connect();
  }

  void Update()
  {
    // Work the dispatched actions on the Unity main thread
    while(_actions.Count > 0)
    {
        if(_actions.TryDequeue(out var action))
        {
            action?.Invoke();
        }
    }

    #if !UNITY_WEBGL || UNITY_EDITOR
      websocket.DispatchMessageQueue();
    #endif
  }

  // async void SendWebSocketMessage()
  // {
  //   if (websocket.State == WebSocketState.Open)
  //   {
  //     // Sending bytes
  //     await websocket.Send(new byte[] { 10, 20, 30 });

  //     // Sending plain text
  //     await websocket.SendText("plain text message");
  //   }
  // }

  private async void OnApplicationQuit()
  {
    await websocket.Close();
  }
}
