import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yatzy/application/widget_application_settings.dart';

import '../startup.dart';
import '../states/cubit/state/state_cubit.dart';

@RoutePage()
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewHomeState();
}

class _SettingsViewHomeState extends State<SettingsView>
    with TickerProviderStateMixin {
  void myState() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    app.tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SetStateCubit, int>(builder: (context, state) {
      return app.widgetScaffoldSettings(context, myState);
    });
  }
}
