import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yatzy/application/widget_application_scaffold.dart';

import '../router/router.gr.dart';
import '../injection.dart';
import '../router/router.dart';
import '../startup.dart';
import '../states/cubit/state/state_cubit.dart';

@RoutePage()
class ApplicationView extends StatefulWidget {
  const ApplicationView({super.key});

  @override
  State<ApplicationView> createState() => _ApplicationViewState();
}

class _ApplicationViewState extends State<ApplicationView>
    with TickerProviderStateMixin {
  void myState() {
    if (mounted) {
       setState(() {});
    }
  }

  void _showGameFinishedDialog() {
    final router = getIt<AppRouter>();
    if (!mounted) return;
    
    String winnerMsg = "Game Over!";

    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Game Finished'),
          content: Text(winnerMsg),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                if (!mounted) return;
                Navigator.of(dialogContext).pop();
                
                app.gameFinished = false;
                
                router.pushAndPopUntil(const SettingsView(), predicate: (_) => false);
                
                app.gameId = -1;
                app.myPlayerId = -1;
              },
            ),
          ],
        );
      },
    );
  }

  postFrameCallback(BuildContext context) async {
    if (mounted) {
      myState();
    }
    mainPageLoaded = true;

    if (app.gameFinished && !app.isSpectating && mounted) {
       _showGameFinishedDialog();
    }
  }

  @override
  void initState() {
    super.initState();
    tutorial.setup(this);

    WidgetsBinding.instance
        .addPostFrameCallback((_) => postFrameCallback(context));

    app.animation.setupAnimation(
        this, app.nrPlayers, app.maxNrPlayers, app.maxTotalFields);

  }

  @override
  void dispose() {
    if (animationsScroll.animationController.isAnimating) {
        animationsScroll.animationController.dispose(); 
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (app.gameFinished && !app.isSpectating && mounted) {
        _showGameFinishedDialog();
      }
    });

    return BlocBuilder<SetStateCubit, int>(builder: (context, state) {
      return app.widgetScaffold(context, myState);
    });
  }
}
