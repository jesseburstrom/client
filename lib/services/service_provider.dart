import 'package:flutter/material.dart';

import 'socket_service.dart';
import 'game_service.dart';

/// Provider for accessing application services
class ServiceProvider extends InheritedWidget {
  /// Socket service instance
  final SocketService socketService;
  
  /// Game service instance
  final GameService gameService;
  
  /// Constructor
  const ServiceProvider({
    Key? key,
    required Widget child,
    required this.socketService,
    required this.gameService,
  }) : super(key: key, child: child);
  
  /// Get the service provider from context
  static ServiceProvider of(BuildContext context) {
    final ServiceProvider? result = 
      context.dependOnInheritedWidgetOfExactType<ServiceProvider>();
    assert(result != null, 'No ServiceProvider found in context');
    return result!;
  }
  
  /// Initialize services and wrap the app with the provider
  static Widget initialize({required Widget child, required BuildContext context}) {
    // Create socket service
    final socketService = SocketService(context: context);
    
    // Create game service
    final gameService = GameService(
      socketService: socketService,
      onError: (message) {
        // Show error message (can be implemented later)
        print('Game error: $message');
      },
    );
    
    // Return provider with services
    return ServiceProvider(
      socketService: socketService,
      gameService: gameService,
      child: child,
    );
  }
  
  @override
  bool updateShouldNotify(ServiceProvider oldWidget) {
    return socketService != oldWidget.socketService || 
           gameService != oldWidget.gameService;
  }
}
