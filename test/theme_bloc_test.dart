import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cchess/chess/theme/asset_board_theme.dart';
import 'package:flutter_cchess/theme/bloc/theme_bloc.dart';
import 'package:flutter_cchess/theme/themes/board_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a late theme load cannot replace a newer selection', () async {
    const olderConfig = 'assets/skins/night/config.json';
    const newerConfig = 'assets/skins/qqclassic/config.json';
    final pending = <String, Completer<BoardTheme>>{};
    final started = <String, Completer<void>>{};

    Future<BoardTheme> loadTheme(String configAsset) {
      started.putIfAbsent(configAsset, Completer<void>.new).complete();
      return pending.putIfAbsent(configAsset, Completer<BoardTheme>.new).future;
    }

    final bloc = ThemeBloc(skinLoader: loadTheme);
    addTearDown(bloc.close);

    bloc.add(const ThemeAssetRequested(olderConfig));
    await started.putIfAbsent(olderConfig, Completer<void>.new).future;
    bloc.add(const ThemeAssetRequested(newerConfig));
    await started.putIfAbsent(newerConfig, Completer<void>.new).future;

    final newerTheme = await AssetBoardTheme.load(newerConfig);
    final newerState = bloc.stream.firstWhere(
      (state) => state.theme.boardAsset == newerTheme.boardAsset,
    );
    pending[newerConfig]!.complete(newerTheme);
    await newerState;

    pending[olderConfig]!.complete(await AssetBoardTheme.load(olderConfig));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.theme.boardAsset, newerTheme.boardAsset);
  });
}
