import 'package:flutter_bloc/flutter_bloc.dart';

class SetStateCubit extends Cubit<int> {
  SetStateCubit() : super(0);

  Future<void> setState() async {
    emit(state + 1);
  }
}
