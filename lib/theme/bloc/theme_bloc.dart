import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_cchess/chess/theme/wood_theme.dart';
import 'package:flutter_cchess/theme/themes/board_theme.dart';

part 'theme_event.dart';
part 'theme_state.dart';

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  ThemeBloc()
      : super(ThemeState(
          theme: const WoodsBoardTheme(),
        )) {
    on<ThemeUpdated>(_onUpdated);
  }

  FutureOr<void> _onUpdated(ThemeUpdated event, Emitter<ThemeState> emit) {
    emit(ThemeState(theme: event.theme));
  }
}
