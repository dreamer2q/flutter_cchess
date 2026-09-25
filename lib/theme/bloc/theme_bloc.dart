import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_cchess/chess/theme/asset_board_theme.dart';
import 'package:flutter_cchess/chess/theme/wood_theme.dart';
import 'package:flutter_cchess/theme/themes/board_theme.dart';

part 'theme_event.dart';
part 'theme_state.dart';

typedef BoardThemeLoader = Future<BoardTheme> Function(String configAsset);

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  ThemeBloc({BoardThemeLoader? skinLoader})
    : _skinLoader = skinLoader ?? AssetBoardTheme.load,
      super(ThemeState(theme: const WoodsBoardTheme())) {
    on<ThemeUpdated>(_onUpdated);
    on<ThemeAssetRequested>(_onAssetRequested);
  }

  final BoardThemeLoader _skinLoader;
  int _assetRequestGeneration = 0;

  FutureOr<void> _onUpdated(ThemeUpdated event, Emitter<ThemeState> emit) {
    _assetRequestGeneration++;
    emit(ThemeState(theme: event.theme));
  }

  Future<void> _onAssetRequested(
    ThemeAssetRequested event,
    Emitter<ThemeState> emit,
  ) async {
    final requestGeneration = ++_assetRequestGeneration;
    final theme = await _skinLoader(event.configAsset);
    if (requestGeneration != _assetRequestGeneration) return;
    emit(ThemeState(theme: theme));
  }
}
