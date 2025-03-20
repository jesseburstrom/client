import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yatzy/application/communication_application.dart';
import 'package:yatzy/dices/dices.dart';
import 'package:yatzy/services/service_provider.dart';
import '../application/application.dart';
import '../chat/chat.dart';
import '../injection.dart';
import '../net/net.dart';
import '../router/router.dart';
import '../scroll/animations_scroll.dart';
import '../startup.dart';
import '../states/cubit/state/state_cubit.dart';
import '../top_score/top_score.dart';
import '../tutorial/tutorial.dart';

class AppWidget extends StatelessWidget {
  AppWidget({Key? key}) : super(key: key);

  final _appRouter = getIt<AppRouter>();

  String getChosenLanguage() {
    return chosenLanguage;
  }

  @override
  Widget build(BuildContext context) {
    // Initialize legacy networking - but do not connect to server
    // We'll manage the connection via the SocketService
    net = Net(context: context);
    
    // Initialize application components
    topScore = TopScore(
        getChosenLanguage: getChosenLanguage,
        standardLanguage: standardLanguage,
        net: net);
    animationsScroll = AnimationsScroll(
        getChosenLanguage: getChosenLanguage,
        standardLanguage: standardLanguage);
    tutorial = Tutorial();
    dices = Dices(
        getChosenLanguage: getChosenLanguage,
        standardLanguage: standardLanguage,
        setState: () => context.read<SetStateCubit>().setState(),
        inputItems: inputItems);
    app =
        Application(context: context, gameDices: dices, inputItems: inputItems);
    chat = Chat(
        getChosenLanguage: getChosenLanguage,
        standardLanguage: standardLanguage,
        callback: app.chatCallbackOnSubmitted,
        setState: () => context.read<SetStateCubit>().setState(),
        inputItems: inputItems);
    
    // Set up callbacks for legacy networking
    net.setCallbacks(
      (data) => app.callbackOnClientMsg(data), 
      (data) => app.callbackOnServerMsg(data)
    );
    
    // Initialize modern service architecture wrapped around the router
    return ServiceProvider.initialize(
      context: context,
      child: MaterialApp.router(
        title: 'Yatzy Game',
        debugShowCheckedModeBanner: false,
        routerDelegate: _appRouter.delegate(),
        routeInformationParser: _appRouter.defaultRouteParser(),
        theme: ThemeData(
          primarySwatch: Colors.blueGrey,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        builder: (context, child) {
          // After the app is built, connect to the socket server once
          // using the service provider's socket service
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final service = ServiceProvider.of(context);
            
            print('🔄 AppWidget: Initializing network connectivity');
            // Only connect if not already connected
            if (!service.socketService.isConnected) {
              print('🔌 AppWidget: Connecting modern SocketService');
              service.socketService.connect();
              
              // For proper multiplayer functionality, we need to initialize the legacy socket
              // but we don't connect it directly - we'll synchronize through the SocketService
              print('🔄 AppWidget: Setting up legacy Net socket for multiplayer compatibility');
              net.initializeSocket();
            }
            
            // Connect the Application instance with the SocketService to enable
            // multiplayer dice synchronization
            print('🔄 AppWidget: Connecting modern SocketService to Application instance');
            app.setSocketService(service.socketService);
          });
          return child!;
        },
      ),
    );
  }
}
