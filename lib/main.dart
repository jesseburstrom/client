import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yatzy/states/bloc/language/language_bloc.dart';
import 'package:yatzy/states/cubit/state/state_cubit.dart';
import 'package:injectable/injectable.dart';
import 'core/app_widget.dart';
import 'injection.dart';
import 'shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPrefProvider.loadPrefs();
  await configureInjection(Environment.dev);
  runApp(
    MultiBlocProvider(providers: [
      BlocProvider(create: (_) => LanguageBloc()),
      BlocProvider(create: (_) => SetStateCubit()),
    ], child: AppWidget()),
  );
}
