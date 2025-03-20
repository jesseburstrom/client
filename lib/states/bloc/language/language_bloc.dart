import 'package:injectable/injectable.dart';

import '../../../shared_preferences.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'language_event.dart';

@injectable
class LanguageBloc extends Bloc<LanguageEvent, String> {
  LanguageBloc() : super(SharedPrefProvider.fetchPrefString(key)) {
    on<LanguageChanged>(_languageChanged);
  }

  static const String key = 'LanguageBloc';

  Future<void> _languageChanged(
      LanguageChanged event, Emitter<String> emit) async {
    SharedPrefProvider.setPrefString(key, event.language);
    emit(event.language);
  }
}
