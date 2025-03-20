// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: unnecessary_lambdas
// ignore_for_file: lines_longer_than_80_chars
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:get_it/get_it.dart' as _i1;
import 'package:injectable/injectable.dart' as _i2;

import 'core/injectable_modules.dart' as _i6;
import 'router/router.dart' as _i3;
import 'states/bloc/language/language_bloc.dart' as _i4;
import 'states/cubit/state/state_cubit.dart' as _i5;

extension GetItInjectableX on _i1.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i1.GetIt init({
    String? environment,
    _i2.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i2.GetItHelper(
      this,
      environment,
      environmentFilter,
    );
    final injectableModule = _$InjectableModule();
    gh.lazySingleton<_i3.AppRouter>(() => injectableModule.router);
    gh.factory<_i4.LanguageBloc>(() => _i4.LanguageBloc());
    gh.factory<_i5.SetStateCubit>(() => _i5.SetStateCubit());
    return this;
  }
}

class _$InjectableModule extends _i6.InjectableModule {}
