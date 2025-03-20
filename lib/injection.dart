import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'injection.config.dart';

final GetIt getIt = GetIt.instance;

@InjectableInit(
  initializerName: 'initApiInjection', // default
  preferRelativeImports: true, // default
  asExtension: true, // default
)
Future configureInjection(final String environment) async {
  getIt.init(environment: environment);
}
