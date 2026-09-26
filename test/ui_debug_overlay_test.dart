import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show debugPaintSizeEnabled;
import 'package:flutter/services.dart';
import 'package:flutter_cchess/debug/ui_debug_overlay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'debug panel opens from its button and reports viewport metrics',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 600);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) =>
              UiDebugOverlay(child: child ?? const SizedBox.shrink()),
          home: const Scaffold(body: Center(child: Text('内容'))),
        ),
      );

      expect(find.text('UI 调试'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('ui-debug-toggle')));
      await tester.pumpAndSettle();

      expect(find.text('UI 调试'), findsOneWidget);
      expect(find.textContaining('视口  800 × 600 dp'), findsOneWidget);
      expect(find.textContaining('DPR  1.00'), findsOneWidget);
      expect(find.byKey(const ValueKey('ui-debug-safe-area')), findsOneWidget);
    },
  );

  testWidgets('F10 toggles panel and render diagnostics can be switched', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            UiDebugOverlay(child: child ?? const SizedBox.shrink()),
        home: const Scaffold(body: Center(child: Text('内容'))),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.f10);
    await tester.pumpAndSettle();
    expect(find.text('UI 调试'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('ui-debug-layout-bounds')),
        matching: find.byType(Switch),
      ),
    );
    await tester.pumpAndSettle();
    expect(debugPaintSizeEnabled, isTrue);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('ui-debug-layout-bounds')),
        matching: find.byType(Switch),
      ),
    );
    await tester.pumpAndSettle();
    expect(debugPaintSizeEnabled, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.f10);
    await tester.pumpAndSettle();
    expect(find.text('UI 调试'), findsNothing);
  });

  testWidgets('alignment guides fit a compact viewport', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            UiDebugOverlay(child: child ?? const SizedBox.shrink()),
        home: const Scaffold(body: Center(child: Text('内容'))),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('ui-debug-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('ui-debug-grid')),
        matching: find.byType(Switch),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ui-debug-guides')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
