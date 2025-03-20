import 'package:auto_route/auto_route.dart';
import 'package:yatzy/router/router.gr.dart';

@AutoRouterConfig()
class AppRouter extends $AppRouter {
  @override
  RouteType get defaultRouteType => const RouteType.material();
  @override
  List<AutoRoute> get routes => [
    AutoRoute(page: SettingsView.page, initial: true, path: '/settingsView'),
    AutoRoute(page: ApplicationView.page, path: '/applicationView'),

  ];
}
