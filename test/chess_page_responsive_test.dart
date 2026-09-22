import 'package:flutter/material.dart';
import 'package:flutter_cchess/chess/view/chess_page.dart';
import 'package:flutter_cchess/main.dart';
import 'package:flutter_cchess/settings/settings.dart';
import 'package:flutter_cchess/storage/storage.dart';
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
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact mobile viewport does not overflow', (tester) async {
    await setViewport(tester, const Size(320, 640));
    await openLocalGame(tester);

    expect(find.byType(ChessBoard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop game exposes the inspector beside the board', (
    tester,
  ) async {
    await setViewport(tester, const Size(1200, 800));
    await openLocalGame(tester);

    expect(find.byType(ChessBoard), findsOneWidget);
    expect(find.text('局面'), findsOneWidget);
    expect(find.text('棋谱将在落子后显示'), findsOneWidget);
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
