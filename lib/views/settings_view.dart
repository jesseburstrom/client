import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yatzy/application/communication_application.dart';
import 'package:yatzy/application/widget_application_settings.dart';
import 'package:yatzy/services/service_provider.dart';

import '../startup.dart';
import '../states/cubit/state/state_cubit.dart';

@RoutePage()
class SettingsView extends StatefulWidget {
  const SettingsView({Key? key}) : super(key: key);

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
    
    // Set up callbacks for legacy net, but DO NOT connect to server
    // We're already connected via SocketService
    net.setCallbacks(app.callbackOnClientMsg, app.callbackOnServerMsg);
    
    // The line below is causing a duplicate socket connection
    // Removed: net.connectToServer();
    
    print('🔍 SettingsView initState called - NOT connecting to server');
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SetStateCubit, int>(builder: (context, state) {
      return app.widgetScaffoldSettings(context, myState);
    });
  }
}
