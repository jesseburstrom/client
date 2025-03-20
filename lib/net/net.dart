import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart';
import 'package:socket_io_client/socket_io_client.dart';
import 'package:flutter/cupertino.dart';

import '../services/service_provider.dart';
import '../startup.dart';
import '../states/cubit/state/state_cubit.dart';

class Net {
  final BuildContext context;
  
  // Debug flag to track initialization
  bool _isInitialized = false;

  // Set to true for ASP .NET server with websocket and false for NodeJS server with socket.io
  Net({required this.context}) {
    print('🔍 [Legacy Net] Created - NO AUTO CONNECT: ${StackTrace.current}');
    _isInitialized = true;
  }

  var socketConnectionId = "";

  late Socket socketConnection;
  late Function callbackOnClientMsg;
  late Function callbackOnServerMsg;

  setCallbacks(Function callbackClient, Function callbackServer) {
    print('🔍 [Legacy Net] setCallbacks called: ${StackTrace.current}');
    callbackOnClientMsg = callbackClient;
    callbackOnServerMsg = callbackServer;
  }

  sendToClients(Map<String, dynamic> msg) {
    if (!_isInitialized || !_hasSocketConnection()) {
      print('❌ [Legacy Net] Cannot send to clients: Socket not initialized');
      return;
    }

    msg["timestamp"] = DateTime.now().millisecondsSinceEpoch;

    socketConnection.emit(
      "sendToClients",
      msg,
    );
  }

  sendToServer(Map<String, dynamic> msg) async {
    if (!_isInitialized || !_hasSocketConnection()) {
      print('❌ [Legacy Net] Cannot send to server: Socket not initialized');
      return;
    }

    msg["timestamp"] = DateTime.now().millisecondsSinceEpoch;

    socketConnection.emit(
      "sendToServer",
      msg,
    );
  }

  onClientMsg(var data) {
    print('📩 [Legacy Net] onClientMsg received: $data');
    if (!_isInitialized) return;
    
    callbackOnClientMsg(data);
    context.read<SetStateCubit>().setState();
  }

  onServerMsg(var data) {
    print('📩 [Legacy Net] onServerMsg received: $data');
    if (!_isInitialized) return;
    
    callbackOnServerMsg(data);
    context.read<SetStateCubit>().setState();
  }

  onConnect(data) {
    print('✅ [Legacy Net] onConnect fired: $data');
    if (!_isInitialized) return;
    
    // Instead of directly requesting ID, check if we already have an ID from SocketService
    if (socketConnectionId == "") {
      print('🆔 [Legacy Net] No ID yet, requesting from server');
      Map<String, dynamic> msg = {};
      msg["action"] = "getId";
      msg["id"] = "";
      //final serviceProvider = ServiceProvider.of(context);
      //serviceProvider.socketService.sendToServer(msg);
      sendToServer(msg);
    } else {
      print('🆔 [Legacy Net] Already have ID from SocketService: $socketConnectionId');
    }
  }

  // Check if socket connection is initialized and connected
  bool _hasSocketConnection() {
    try {
      // This will throw if socketConnection is not initialized
      return socketConnection != null && socketConnection.connected;
    } catch (e) {
      return false;
    }
  }

  // Initialize socket without connecting
  void initializeSocket() {
    print('🔌 [Legacy Net] Initializing socket without connecting');
    
    if (_hasSocketConnection()) {
      print('🚫 [Legacy Net] Socket already initialized');
      return;
    }
    
    try {
      print('🔌 [Legacy Net] Setting up socket connection to $localhost');
      // Configure socket, transports must be specified
      socketConnection = io(localhost, <String, dynamic>{
        "transports": ["websocket"],
        'autoConnect': false, // Prevent auto-connection
      });
      
      // Set up event handlers
      socketConnection.onConnect(onConnect);
      socketConnection.on("onClientMsg", onClientMsg);
      socketConnection.on("onServerMsg", onServerMsg);
      
      print('✅ [Legacy Net] Socket initialized successfully but NOT connected');
    } catch (e) {
      print('❌ [Legacy Net] Error initializing socket: $e');
    }
  }

  connectToServer() async {
    print('🔌 [Legacy Net] connectToServer called from: ${StackTrace.current}');
    
    if (_hasSocketConnection()) {
      print('🚫 [Legacy Net] Already connected, skipping connection');
      return;
    }
    
    try {
      print('🔌 [Legacy Net] Connecting to $localhost');
      socketConnection.connect();
    } catch (e) {
      print('❌ [Legacy Net] Error connecting to server: $e');
    }
  }

  // Http

  Future getDB(String route) async {
    return await get(Uri.parse(localhost + route), headers: <String, String>{
      "Content-Type": "application/json; charset=UTF-8",
    });
  }

  Future postDB(String route, Map<String, dynamic> json) async {
    return await post(Uri.parse(localhost + route),
        headers: <String, String>{
          "Content-Type": "application/json; charset=UTF-8",
        },
        body: jsonEncode(json));
  }

  Future updateDB(String route, Map<String, dynamic> json) async {
    return await post(Uri.parse(localhost + route),
        headers: <String, String>{
          "Content-Type": "application/json; charset=UTF-8",
        },
        body: jsonEncode(json));
  }

  Future deleteDB(String route) async {
    return await delete(Uri.parse(localhost + route), headers: <String, String>{
      "Content-Type": "application/json; charset=UTF-8",
    });
  }

  Future deleteUser(String route, String email) async {
    return await delete(Uri.parse("$localhost$route?email=$email"),
        headers: <String, String>{
          "Content-Type": "application/json; charset=UTF-8",
        });
  }

  Future login(String userName, String password) async {
    return await post(Uri.parse("$localhost/Login"),
        headers: <String, String>{
          "Content-Type": "application/json; charset=UTF-8",
        },
        body: jsonEncode(<String, String>{
          "email": userName,
          "password": password,
        }));
  }

  Future signup(String userName, String password) async {
    return await post(Uri.parse("$localhost/Signup"),
        headers: <String, String>{
          "Content-Type": "application/json; charset=UTF-8",
        },
        body: jsonEncode(<String, String>{
          "email": userName,
          "password": password,
        }));
  }
}
