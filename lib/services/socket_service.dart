import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:convert';

import '../models/game.dart';
import '../models/player.dart';
import '../states/cubit/state/state_cubit.dart';
import '../startup.dart';

/// Service responsible for managing Socket.IO connections with the game server
class SocketService {
  // Identity tracking for logging purposes
  static int _instanceCounter = 0;
  final int _instanceId;
  
  final BuildContext context;
  
  /// Socket.IO connection instance
  late io.Socket socket;
  
  /// ID assigned by the server
  String socketId = '';
  
  /// Whether the socket is connected
  bool isConnected = false;
  
  /// Game instance
  Game? game;
  
  /// Connection in progress flag to prevent multiple connection attempts
  bool _connectingInProgress = false;
  
  /// Static tracking of global connection to prevent duplicate connections app-wide
  static bool _globalConnectionInProgress = false;
  
  /// Stack trace of connection initiation for debugging
  static String? _connectionInitiator;
  
  /// Callback when game updates are received
  Function(Game)? onGameUpdate;
  
  /// Callback when chat messages are received
  Function(Map<String, dynamic>)? onChatMessage;
  
  /// Creates a new SocketService instance
  SocketService({required this.context}) : _instanceId = ++_instanceCounter {
    print('🔍 SocketService instance #$_instanceId created: ${StackTrace.current}');
  }
  
  /// Initialize and connect to the Socket.IO server
  void connect() {
    // Get caller stack trace for debugging
    final stackTrace = StackTrace.current.toString();
    print('🔍 SocketService #$_instanceId connect() called from:\n$stackTrace');
    
    // Prevent multiple connection attempts at the application level
    if (_globalConnectionInProgress) {
      print('🚫 [Socket #$_instanceId] Global connection already in progress, skipping additional attempt');
      print('   Original connection initiated from: $_connectionInitiator');
      return;
    }
    
    // Prevent multiple connection attempts at the instance level
    if (_connectingInProgress) {
      print('🚫 [Socket #$_instanceId] Connection already in progress, skipping additional attempt');
      return;
    }
    
    // Check if already connected
    if (isConnected) {
      print('🚫 [Socket #$_instanceId] Already connected to server, skipping additional connection attempt');
      return;
    }
    
    _connectingInProgress = true;
    _globalConnectionInProgress = true;
    _connectionInitiator = stackTrace;
    
    print('🔌 [Socket #$_instanceId] Initiating connection to server: $localhost');
    
    try {
      // Initialize socket with proper options - ONLY ONCE
      socket = io.io(
        localhost, 
        <String, dynamic>{
          'transports': ['websocket', 'polling'],
          'autoConnect': false,  // Start with autoConnect off
          'forceNew': true,
          'reconnection': true,
          'reconnectionAttempts': 3,
          'reconnectionDelay': 1000,
          'reconnectionDelayMax': 5000,
          'timeout': 20000,
          'extraHeaders': {'Content-Type': 'application/json'}
        }
      );
      
      // Set up event handlers before connection
      _setupEventHandlers();
      
      // Now manually connect after event handlers are set up
      print('🔌 [Socket #$_instanceId] Socket initialized, now connecting...');
      socket.connect();
      
      // Debug connection status after a reasonable delay
      Future.delayed(Duration(seconds: 3), () {
        print('🔍 [Socket #$_instanceId] Connection status after 3s: ${socket.connected ? '✅ Connected' : '❌ Not connected'}');
        _connectingInProgress = false;
        _globalConnectionInProgress = false;
      });
    } catch (e) {
      print('❌ [Socket #$_instanceId] Error initializing socket connection: $e');
      _connectingInProgress = false;
      _globalConnectionInProgress = false;
    }
  }
  
  /// Set up Socket.IO event handlers
  void _setupEventHandlers() {
    print('🔄 [Socket #$_instanceId] Setting up event handlers');
    
    // Connection events
    socket.onConnect((_) {
      print('✅ [Socket #$_instanceId] Connected to server with socket ID: ${socket.id}');
      isConnected = true;
      socketId = socket.id ?? '';
      
      // Test the connection by sending an echo
      _sendEcho();
      
      // Request ID from server
      _requestId();
      
      // Sync with legacy Net
      _syncWithLegacyNet();
      
      // Notify UI to update
      _updateState();
    });
    
    socket.onDisconnect((_) {
      print('❌ [Socket #$_instanceId] Disconnected from server');
      isConnected = false;
      _updateState();
    });
    
    socket.onConnectError((error) {
      print('❌ [Socket #$_instanceId] Connection error: $error');
      isConnected = false;
      _updateState();
    });
    
    // Welcome event to confirm connection
    socket.on('welcome', (data) {
      print('📩 [Socket #$_instanceId] Received welcome message: $data');
      if (data is Map && data['id'] != null) {
        socketId = data['id'];
        print('🆔 [Socket #$_instanceId] Server assigned ID: $socketId');
      }
      _updateState();
    });
    
    // Echo response for testing
    socket.on('echo_response', (data) {
      print('📩 [Socket #$_instanceId] Received echo response: $data');
    });
    
    // Game-related events
    socket.on('onClientMsg', _handleClientMessage);
    socket.on('onServerMsg', _handleServerMessage);
    
    // Additional events
    socket.on('userId', _handleUserId);
    socket.on('gameUpdate', _handleGameUpdate);
    socket.on('chatMessage', _handleChatMessage);
  }
  
  /// Send an echo message to test the connection
  void _sendEcho() {
    final msg = {
      'message': 'Connection test',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    print('📤 [Socket #$_instanceId] Sending echo test: ${jsonEncode(msg)}');
    socket.emit('echo', msg);
  }
  
  /// Request user ID from server
  void _requestId() {
    Map<String, dynamic> msg = {
      'action': 'getId',
      'id': '',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    print('📤 [Socket #$_instanceId] Requesting ID from server');
    socket.emit('sendToServer', msg);
  }
  
  /// Forward socket events to legacy Net
  void _syncWithLegacyNet() {
    if (!isConnected) return;
    
    try {
      final netInstance = net;
      if (netInstance != null && netInstance.socketConnection != null) {
        print('🔄 [Socket #$_instanceId] Syncing with legacy Net - forwarding connection state');
        
        // Set the socketConnectionId in legacy Net
        netInstance.socketConnectionId = socketId;
        
        // Important: For multiplayer functionality, ensure legacy event handlers are registered
        print('🔄 [Socket #$_instanceId] Ensuring legacy event handlers are registered');
        
        // For multiplayer functionality to work properly, we need to "connect" the legacy net's socket
        // without actually creating a new connection to the server
        if (!netInstance.socketConnection.connected) {
          print('🔄 [Socket #$_instanceId] Updating legacy Net connection state to connected');
          // This makes the legacy system think it's connected without making a new connection
          netInstance.socketConnection.id = socketId;
          
          // We don't call the connect method since that would create a duplicate connection
          // Instead, let's manually fire the onConnect event
          netInstance.onConnect(null);
        }
      }
    } catch (e) {
      print('❌ [Socket #$_instanceId] Error syncing with legacy Net: $e');
    }
  }
  
  /// Handle user ID received from server
  void _handleUserId(dynamic data) {
    print('📩 [Socket #$_instanceId] Received user ID: $data');
    
    if (data is Map && data['id'] != null) {
      socketId = data['id'];
      
      // Important: Update the legacy Net socketConnectionId to maintain compatibility
      try {
        final netInstance = net;
        if (netInstance != null) {
          print('🔄 [Socket #$_instanceId] Synchronizing socketId with legacy Net: $socketId');
          netInstance.socketConnectionId = socketId;
        }
      } catch (e) {
        print('❌ [Socket #$_instanceId] Error synchronizing socketId: $e');
      }
      
      _updateState();
    }
  }
  
  /// Handle client messages
  void _handleClientMessage(dynamic data) {
    print('📩 [Socket #$_instanceId] Received client message: $data');
    
    // Forward message to legacy system
    try {
      // Get the Net instance from startup
      final netInstance = net;
      if (netInstance != null && netInstance.callbackOnClientMsg != null) {
        print('🔄 [Socket #$_instanceId] Forwarding client message to legacy callback');
        netInstance.callbackOnClientMsg(data);
      }
    } catch (e) {
      print('❌ [Socket #$_instanceId] Error forwarding to legacy callback: $e');
    }
    
    _updateState();
  }
  
  /// Handle server messages
  void _handleServerMessage(dynamic data) {
    print('📩 [Socket #$_instanceId] Received server message: $data');
    
    // Forward message to legacy system if callbacks are registered in Net class
    try {
      // Get the Net instance from startup
      final netInstance = net;
      if (netInstance != null && netInstance.callbackOnServerMsg != null) {
        print('🔄 [Socket #$_instanceId] Forwarding server message to legacy callback');
        netInstance.callbackOnServerMsg(data);
      }
    } catch (e) {
      print('❌ [Socket #$_instanceId] Error forwarding to legacy callback: $e');
    }
    
    // Also process in modern system if registered
    if (data is Map<String, dynamic>) {
      final action = data['action'];
      if (action == 'onGameStart') {
        print('🎮 [Socket #$_instanceId] Game start event received');
        _processGameUpdate(data);
      } else if (action == 'onGameUpdate') {
        print('🎮 [Socket #$_instanceId] Game update event received');
        _processGameUpdate(data);
      } else if (action == 'onRequestGames') {
        print('🎮 [Socket #$_instanceId] Game list update received');
        // games list is stored in legacy system, no need to duplicate here
      }
    }
    
    _updateState();
  }
  
  /// Handle game update event
  void _handleGameUpdate(dynamic data) {
    print('📩 [Socket #$_instanceId] Game update received');
    
    if (data is Map<String, dynamic>) {
      _processGameUpdate(data);
    }
    
    _updateState();
  }
  
  /// Process game update data
  void _processGameUpdate(Map<String, dynamic> gameData) {
    // Create game instance from data
    game = Game.fromJson(gameData);
    
    // Find player index based on my socket ID
    if (game != null) {
      // Update my player index
      for (int i = 0; i < game!.players.length; i++) {
        if (game!.players[i].id == socketId) {
          game!.myPlayerIndex = i;
          break;
        }
      }
      
      // Notify listeners
      if (onGameUpdate != null) {
        onGameUpdate!(game!);
      }
    }
  }
  
  /// Handle chat message event
  void _handleChatMessage(dynamic data) {
    print('📩 [Socket #$_instanceId] Chat message received: $data');
    
    if (onChatMessage != null && data is Map<String, dynamic>) {
      onChatMessage!(data);
    }
  }
  
  /// Create a new game
  void createGame({
    required String gameType,
    required int maxPlayers,
    required String username,
  }) {
    if (!isConnected) {
      print('❌ [Socket #$_instanceId] Cannot create game: Not connected to server');
      return;
    }
    
    Map<String, dynamic> msg = {
      'action': 'createGame',
      'gameType': gameType,
      'nrPlayers': maxPlayers,
      'userName': username,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    print('📤 [Socket #$_instanceId] Creating game: $msg');
    socket.emit('sendToServer', msg);
  }
  
  /// Join an existing game
  void joinGame({
    required int gameId,
    required String username,
  }) {
    if (!isConnected) {
      print('❌ [Socket #$_instanceId] Cannot join game: Not connected to server');
      return;
    }
    
    Map<String, dynamic> msg = {
      'action': 'joinGame',
      'gameId': gameId,
      'userName': username,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    print('📤 [Socket #$_instanceId] Joining game: $msg');
    socket.emit('sendToServer', msg);
  }
  
  /// Roll dice
  void rollDice({
    required int gameId,
    required List<bool> keepDice,
  }) {
    if (!isConnected || game == null) {
      print('❌ [Socket #$_instanceId] Cannot roll dice: Not connected or no active game');
      return;
    }
    
    Map<String, dynamic> msg = {
      'action': 'rollDice',
      'gameId': gameId,
      'keepDice': keepDice,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    print('📤 [Socket #$_instanceId] Rolling dice: $msg');
    socket.emit('sendToServer', msg);
  }
  
  /// Select a cell for scoring
  void selectCell({
    required int gameId,
    required int cellIndex,
  }) {
    if (!isConnected || game == null) {
      print('❌ [Socket #$_instanceId] Cannot select cell: Not connected or no active game');
      return;
    }
    
    Map<String, dynamic> msg = {
      'action': 'selectCell',
      'gameId': gameId,
      'cellIndex': cellIndex,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    print('📤 [Socket #$_instanceId] Selecting cell: $msg');
    socket.emit('sendToServer', msg);
  }
  
  /// Send a chat message
  void sendChatMessage({
    required int gameId,
    required String message,
  }) {
    if (!isConnected) {
      print('❌ [Socket #$_instanceId] Cannot send chat message: Not connected to server');
      return;
    }
    
    Map<String, dynamic> msg = {
      'action': 'chatMessage',
      'gameId': gameId,
      'message': message,
      'sender': userName,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    print('📤 [Socket #$_instanceId] Sending chat message: $msg');
    socket.emit('sendToServer', msg);
  }
  
  /// Send a message to all clients in the room
  void sendToClients(Map<String, dynamic> data) {
    if (!isConnected) {
      print('❌ [Socket #$_instanceId] Cannot send to clients: Not connected');
      return;
    }
    
    print('📤 [Socket #$_instanceId] Sending to clients: $data');
    
    // Add timestamp if not present
    if (!data.containsKey('timestamp')) {
      data['timestamp'] = DateTime.now().millisecondsSinceEpoch;
    }
    
    // For dice-related events, ensure proper handling
    if (data['action'] == 'sendDices') {
      print('🎲 [Socket #$_instanceId] Sending dice values: ${data['diceValue']}');
    }
    
    // Emit the event through Socket.IO
    socket.emit('sendToClients', data);
  }
  
  /// Send a message to the server
  void sendToServer(Map<String, dynamic> data) {
    if (!isConnected) {
      print('❌ [Socket #$_instanceId] Cannot send to server: Not connected');
      return;
    }
    
    // Add timestamp
    data['timestamp'] = DateTime.now().millisecondsSinceEpoch;
    
    print('📤 [Socket #$_instanceId] Sending to server: ${jsonEncode(data)}');
    socket.emit('sendToServer', data);
  }
  
  /// Disconnect from the server
  void disconnect() {
    if (isConnected) {
      print('🔌 [Socket #$_instanceId] Disconnecting from server');
      socket.disconnect();
      isConnected = false;
    }
  }
  
  /// Update the UI state
  void _updateState() {
    try {
      context.read<SetStateCubit>().setState();
    } catch (e) {
      print('❌ [Socket #$_instanceId] Error updating state: $e');
    }
  }
}
