import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yatzy/application/communication_application.dart';
import 'package:yatzy/dices/dices.dart';
import 'package:yatzy/services/service_provider.dart';
import '../application/application.dart';
import '../chat/chat.dart';
import '../injection.dart';
import '../router/router.dart';
import '../startup.dart';
import '../states/cubit/state/state_cubit.dart';
import '../top_score/top_score.dart';

class AppWidget extends StatelessWidget {
  AppWidget({super.key});

  final _appRouter = getIt<AppRouter>();

  String getChosenLanguage() {
    return app.chosenLanguage;
  }

  @override
  Widget build(BuildContext context) {

    // Initialize application components
    topScore = TopScore(
        getChosenLanguage: getChosenLanguage,
        standardLanguage: standardLanguage);

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
            try {
              final service = ServiceProvider.of(context);
              
              print('🔄 AppWidget: Initializing network connectivity');
              // Only connect if not already connected
              if (!service.socketService.isConnected) {
                print('🔌 AppWidget: Connecting modern SocketService');
                service.socketService.connect();
              }
              
              // Connect the Application instance with the SocketService to enable
              // multiplayer dice synchronization
              print('🔄 AppWidget: Connecting modern SocketService to Application instance');
              app.setSocketService(service.socketService);
            } catch (e) {
              print('⚠️ ServiceProvider not available in AppWidget: $e');
              print('🔄 AppWidget: Running in offline mode');
              // Continue in offline mode
            }
          });
          return child!;
        },
      ),
    );
  }
}
