import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_cchess/chess/theme/asset_board_theme.dart';
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
    on<ThemeAssetRequested>(_onAssetRequested);
  }

  FutureOr<void> _onUpdated(ThemeUpdated event, Emitter<ThemeState> emit) {
    emit(ThemeState(theme: event.theme));
  }

  Future<void> _onAssetRequested(
    ThemeAssetRequested event,
    Emitter<ThemeState> emit,
  ) async {
    emit(ThemeState(theme: await AssetBoardTheme.load(event.configAsset)));
  }
}
