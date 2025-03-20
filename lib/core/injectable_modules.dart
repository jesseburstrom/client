import 'package:injectable/injectable.dart';

import '../router/router.dart';

@module
abstract class InjectableModule {
  @lazySingleton
  AppRouter get router => AppRouter();
}
