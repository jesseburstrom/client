// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:auto_route/auto_route.dart' as _i3;
import 'package:yatzy/views/application_view.dart' as _i1;
import 'package:yatzy/views/settings_view.dart' as _i2;

abstract class $AppRouter extends _i3.RootStackRouter {
  $AppRouter({super.navigatorKey});

  @override
  final Map<String, _i3.PageFactory> pagesMap = {
    ApplicationView.name: (routeData) {
      return _i3.AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const _i1.ApplicationView(),
      );
    },
    SettingsView.name: (routeData) {
      return _i3.AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const _i2.SettingsView(),
      );
    },
  };
}

/// generated route for
/// [_i1.ApplicationView]
class ApplicationView extends _i3.PageRouteInfo<void> {
  const ApplicationView({List<_i3.PageRouteInfo>? children})
      : super(
          ApplicationView.name,
          initialChildren: children,
        );

  static const String name = 'ApplicationView';

  static const _i3.PageInfo<void> page = _i3.PageInfo<void>(name);
}

/// generated route for
/// [_i2.SettingsView]
class SettingsView extends _i3.PageRouteInfo<void> {
  const SettingsView({List<_i3.PageRouteInfo>? children})
      : super(
          SettingsView.name,
          initialChildren: children,
        );

  static const String name = 'SettingsView';

  static const _i3.PageInfo<void> page = _i3.PageInfo<void>(name);
}
