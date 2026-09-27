import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cchess/chess/theme/board_corner_marker.dart';
import 'package:flutter_cchess/chess/view/chess_page.dart';
import 'package:flutter_cchess/chess/bloc/chess_bloc.dart';
import 'package:flutter_cchess/chess/game/game_board.dart';
import 'package:flutter_cchess/chess/game/ai_strength.dart';
import 'package:flutter_cchess/chess/view/new_chess_page.dart';
import 'package:flutter_cchess/main.dart';
import 'package:flutter_cchess/settings/settings.dart';
import 'package:flutter_cchess/storage/storage.dart';
import 'package:flutter_cchess/theme/bloc/theme_bloc.dart';
import 'package:flutter_cchess/utils/fen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> setViewport(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  }

  Future<void> openLocalGame(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesGameSettingsRepository.storageKey: const GameSettings(
        soundEnabled: false,
      ).encode(),
    });
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('本地双人'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('本地双人'));
    await tester.pumpAndSettle();
  }

  Future<void> waitForThemeAsset(WidgetTester tester, String asset) async {
    final bloc = BlocProvider.of<ThemeBloc>(
      tester.element(find.byType(GameSettingsPage)),
    );
    for (
      var frame = 0;
      frame < 50 && bloc.state.theme.boardAsset != asset;
      frame++
    ) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(bloc.state.theme.boardAsset, asset);
  }

  testWidgets('mobile game keeps the board and primary commands visible', (
    tester,
  ) async {
    await setViewport(tester, const Size(390, 844));
    await openLocalGame(tester);

    expect(find.byType(ChessBoard), findsOneWidget);
    expect(find.text('悔棋'), findsOneWidget);
    expect(find.text('翻转'), findsOneWidget);
    expect(find.text('棋谱'), findsOneWidget);
    expect(find.text('红方 · 我'), findsOneWidget);
    expect(find.text('快速估值（红方视角）'), findsOneWidget);
    expect(find.text('评分'), findsOneWidget);

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('暖木经典'));
    await tester.pumpAndSettle();
    await waitForThemeAsset(tester, 'assets/skins/qqclassic/board.png');
    expect(
      BlocProvider.of<ThemeBloc>(
        tester.element(find.byType(GameSettingsPage)),
      ).state.theme.boardAsset,
      'assets/skins/qqclassic/board.png',
    );
    await tester.tap(find.byTooltip('返回对局'));
    await tester.pumpAndSettle();
    expect(
      find.image(const AssetImage('assets/skins/qqclassic/board.png')),
      findsOneWidget,
    );
    expect(find.text('楚河'), findsOneWidget);
    expect(find.text('汉界'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('board taps follow classic skin intersections', (tester) async {
    await setViewport(tester, const Size(390, 844));
    await openLocalGame(tester);

    final boardImage = find.image(
      const AssetImage('assets/skins/woods/board.jpg'),
    );
    expect(boardImage, findsOneWidget);
    final boardRect = tester.getRect(boardImage);
    Offset intersection(int x, int y) => Offset(
      boardRect.left + (32.5 + x * 57) * boardRect.width / 521,
      boardRect.top + (31.5 + y * 57) * boardRect.height / 577,
    );
    final bloc = BlocProvider.of<ChessBloc>(
      tester.element(find.byType(ChessBoard)),
    );

    await tester.tapAt(intersection(0, 9));
    await tester.pump();
    expect(bloc.state.selected?.sq, SquareBoard.coordXYFix(0, 9));

    await tester.tapAt(intersection(0, 8));
    await tester.pump();
    expect(bloc.state.board.lastMoves, hasLength(1));
    expect(
      bloc.state.board.lastMoves.single.sqDst,
      SquareBoard.coordXYFix(0, 8),
    );
  });

  testWidgets('selection uses centered corners without a pointer focus ring', (
    tester,
  ) async {
    await setViewport(tester, const Size(390, 844));
    await openLocalGame(tester);

    final boardRect = tester.getRect(
      find.image(const AssetImage('assets/skins/woods/board.jpg')),
    );
    Offset intersection(int x, int y) => Offset(
      boardRect.left + (32.5 + x * 57) * boardRect.width / 521,
      boardRect.top + (31.5 + y * 57) * boardRect.height / 577,
    );

    await tester.tapAt(intersection(0, 9));
    await tester.pump();
    expect(find.byType(BoardCornerMarker), findsOneWidget);
    expect(find.byKey(const ValueKey('board-keyboard-focus')), findsNothing);
    expect(
      (tester.getCenter(find.byType(BoardCornerMarker)) - intersection(0, 9))
          .distance,
      lessThan(0.1),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.byType(BoardCornerMarker), findsNWidgets(2));
    expect(
      (tester.getCenter(find.byKey(const ValueKey('board-keyboard-focus'))) -
              intersection(1, 9))
          .distance,
      lessThan(0.1),
    );
  });

  testWidgets('compact mobile viewport does not overflow', (tester) async {
    await setViewport(tester, const Size(320, 640));
    await openLocalGame(tester);

    expect(find.byType(ChessBoard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'desktop settings use a split view and apply themes immediately',
    (tester) async {
      await setViewport(tester, const Size(1200, 800));
      await openLocalGame(tester);

      await tester.tap(find.byTooltip('设置'));
      await tester.pumpAndSettle();

      expect(find.byType(GameSettingsPage), findsOneWidget);
      expect(find.text('偏好设置'), findsOneWidget);
      expect(find.text('棋盘外观'), findsNWidgets(2));
      expect(
        tester.getRect(find.byKey(const ValueKey('settings-group-棋盘主题'))).width,
        greaterThan(800),
      );
      await tester.tap(find.text('夜间胡桃木'));
      await tester.pumpAndSettle();
      await waitForThemeAsset(tester, 'assets/skins/night/board.png');
      expect(
        BlocProvider.of<ThemeBloc>(
          tester.element(find.byType(GameSettingsPage)),
        ).state.theme.boardAsset,
        'assets/skins/night/board.png',
      );
      await tester.tap(find.byTooltip('返回对局'));
      await tester.pumpAndSettle();
      expect(
        find.image(const AssetImage('assets/skins/night/board.png')),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('设置'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SegmentedButton<String>>(
              find.byType(SegmentedButton<String>),
            )
            .selected,
        {'assets/skins/night/config.json'},
      );
      await tester.tap(find.text('暖木经典'));
      await tester.pumpAndSettle();
      await waitForThemeAsset(tester, 'assets/skins/qqclassic/board.png');
      expect(
        tester
            .widget<SegmentedButton<String>>(
              find.byType(SegmentedButton<String>),
            )
            .selected,
        {'assets/skins/qqclassic/config.json'},
      );
      expect(
        BlocProvider.of<ThemeBloc>(
          tester.element(find.byType(GameSettingsPage)),
        ).state.theme.boardAsset,
        'assets/skins/qqclassic/board.png',
      );
      await tester.tap(find.byTooltip('返回对局'));
      await tester.pumpAndSettle();
      expect(
        find.image(const AssetImage('assets/skins/qqclassic/board.png')),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('设置'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('声音与触觉'));
      await tester.pumpAndSettle();
      expect(find.text('对局反馈'), findsOneWidget);
      expect(find.text('触觉反馈'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('new game uses selected time and AI strength', (tester) async {
    await setViewport(tester, const Size(1200, 800));
    SharedPreferences.setMockInitialValues({
      SharedPreferencesGameSettingsRepository.storageKey: const GameSettings(
        soundEnabled: false,
      ).encode(),
    });
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.text('AI 对战'), findsOneWidget);
    expect(find.text('红方电脑'), findsNothing);
    expect(find.text('黑方电脑'), findsNothing);
    await tester.tap(find.text('15 分钟'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5 分钟').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DropdownButtonFormField<int>>(
            find.byType(DropdownButtonFormField<int>),
          )
          .initialValue,
      300,
    );
    await tester.tap(find.text('普通').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('较强').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('人机对局'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<ChessPage>(find.byType(ChessPage)).timeControlSeconds,
      300,
    );
    expect(
      tester.widget<ChessPage>(find.byType(ChessPage)).aiStrength,
      AiStrength.hard,
    );

    final bloc = BlocProvider.of<ChessBloc>(
      tester.element(find.byType(ChessBoard)),
    );
    expect(bloc.state.timeControlSeconds, 300);
    expect(bloc.state.aiStrength, AiStrength.hard);
    expect(bloc.state.aiMaxDepth, AiStrength.hard.maxDepth);
    expect(bloc.state.aiMaxThinkMs, AiStrength.hard.maxThinkMs);
    expect(find.text('05:00'), findsNWidgets(2));
  });

  testWidgets('AI duel options are shown only when starting an AI duel', (
    tester,
  ) async {
    await setViewport(tester, const Size(390, 844));
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('思考深度'), findsNothing);
    expect(find.text('每步之间停顿'), findsNothing);
    await tester.tap(find.text('AI 对战'));
    await tester.pumpAndSettle();

    expect(find.text('红方电脑'), findsOneWidget);
    expect(find.text('黑方电脑'), findsOneWidget);
    expect(find.text('思考深度'), findsNWidgets(2));
    expect(find.text('每步之间停顿'), findsOneWidget);
    expect(find.text('开始对战'), findsOneWidget);
    expect(
      tester
          .widgetList<Slider>(find.byType(Slider))
          .map((slider) => slider.value),
      [8, 8],
    );

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.byType(ChessPage), findsNothing);
  });

  testWidgets('notation file opens a local study game', (tester) async {
    await setViewport(tester, const Size(1200, 800));
    SharedPreferences.setMockInitialValues({
      SharedPreferencesGameSettingsRepository.storageKey: const GameSettings(
        soundEnabled: false,
      ).encode(),
    });
    await tester.pumpWidget(
      MaterialApp(
        home: NewChessPage(
          pickNotationFile: () async => XFile.fromData(
            Uint8List.fromList(utf8.encode('1. h2e2 h7e7 *')),
            name: 'study.pgn',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('导入棋谱'));
    await tester.pumpAndSettle();

    expect(find.byType(ChessBoard), findsOneWidget);
    final bloc = BlocProvider.of<ChessBloc>(
      tester.element(find.byType(ChessBoard)),
    );
    expect(bloc.state.board.lastMoves, hasLength(2));
    expect(bloc.state.timeControlSeconds, 0);
    final preferences = await SharedPreferences.getInstance();
    expect(
      (await SharedPreferencesGameRepository(preferences).getCurrent())?.moves,
      hasLength(2),
    );
  });

  testWidgets('invalid notation does not overwrite local storage', (
    tester,
  ) async {
    await setViewport(tester, const Size(1200, 800));
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        home: NewChessPage(
          pickNotationFile: () async => XFile.fromData(
            Uint8List.fromList(utf8.encode('1. h2e2 h2e2')),
            name: 'invalid.pgn',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('导入棋谱'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(ChessBoard), findsNothing);
    final preferences = await SharedPreferences.getInstance();
    expect(
      await SharedPreferencesGameRepository(preferences).getCurrent(),
      isNull,
    );
  });

  testWidgets('desktop game exposes the inspector beside the board', (
    tester,
  ) async {
    await setViewport(tester, const Size(1200, 800));
    await openLocalGame(tester);

    expect(find.byType(ChessBoard), findsOneWidget);
    expect(find.text('局面'), findsOneWidget);
    expect(find.text('棋谱将在落子后显示'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('棋谱将在落子后显示'),
        matching: find.byType(BackdropFilter),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('局面'));
    await tester.pumpAndSettle();
    expect(find.text('快速估值（红方视角）'), findsOneWidget);
    expect(find.byTooltip('AI评分'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('short desktop window falls back to stacked layout', (
    tester,
  ) async {
    await setViewport(tester, const Size(800, 600));
    await openLocalGame(tester);

    expect(find.byType(ChessBoard), findsOneWidget);
    expect(find.text('局面'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('standard tablet desktop layout remains stable', (tester) async {
    await setViewport(tester, const Size(1024, 768));
    await openLocalGame(tester);

    expect(find.byType(ChessBoard), findsOneWidget);
    expect(find.text('局面'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unfinished local game can be resumed from the home page', (
    tester,
  ) async {
    await setViewport(tester, const Size(1200, 800));
    SharedPreferences.setMockInitialValues({
      SharedPreferencesGameSettingsRepository.storageKey: const GameSettings(
        soundEnabled: false,
      ).encode(),
    });
    final preferences = await SharedPreferences.getInstance();
    final board = FenUtil.parse(initialFenString);
    final move = board.getMoves().first;
    final now = DateTime.utc(2026, 9, 23);
    await SharedPreferencesGameRepository(preferences).save(
      GameRecord(
        id: 'resume-test',
        initialFen: initialFenString,
        moves: [GameMove(from: move.sqSrc, to: move.sqDst)],
        mode: GamePlayMode.self,
        createdAt: now,
        updatedAt: now,
      ),
    );

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.text('继续上局'), findsOneWidget);
    expect(find.text('本地双人 · 1 步'), findsOneWidget);

    await tester.tap(find.text('继续上局'));
    await tester.pumpAndSettle();
    expect(find.byType(ChessBoard), findsOneWidget);
    expect(find.text('棋谱将在落子后显示'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
