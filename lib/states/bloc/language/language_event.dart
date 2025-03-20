

/// Event being processed by [CounterBloc].
abstract class LanguageEvent {}

/// Notifies bloc to increment state.
class LanguageChanged extends LanguageEvent {
  final String language;

  LanguageChanged({required this.language});
}
