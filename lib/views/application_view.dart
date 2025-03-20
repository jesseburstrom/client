import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yatzy/application/widget_application_scaffold.dart';

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
    setState(() {});
  }

  postFrameCallback(BuildContext context) async {
    await topScore.loadTopScoreFromServer(app.gameType);
    myState();
    mainPageLoaded = true;
  }

  @override
  void initState() {
    super.initState();
    app.setup();
    tutorial.setup(this);

    WidgetsBinding.instance
        .addPostFrameCallback((_) => postFrameCallback(context));

    app.animation.setupAnimation(
        this, app.nrPlayers, app.maxNrPlayers, app.maxTotalFields);

  }

  @override
  void dispose() {
    super.dispose();
    animationsScroll.animationController.stop();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SetStateCubit, int>(builder: (context, state) {
      return app.widgetScaffold(context, myState);
    });
  }
}
