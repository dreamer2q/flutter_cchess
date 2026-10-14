import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cchess/chess/view/chess_page.dart';
import 'package:flutter_cchess/main.dart';
import 'package:flutter_cchess/settings/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Optional PNG exports use the same UI paths as the assertions below.
// UI_REVIEW_DIR=/tmp/chess-ui fvm flutter test test/product_experience_test.dart
Future<void> capture(WidgetTester tester, String name) async {
  final output = Platform.environment['UI_REVIEW_DIR'];
  if (output == null) return;
  final images = tester.widgetList<Image>(find.byType(Image)).toList();
  await tester.runAsync(() async {
    for (final image in images) {
      await precacheImage(image.image, tester.element(find.byType(MyApp)));
    }
  });
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('product-review')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(output).create(recursive: true);
      await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  setUpAll(() async {
    if (Platform.environment['UI_REVIEW_DIR'] != null && Platform.isMacOS) {
      final font = FontLoader('Roboto')
        ..addFont(
          File(
            '/System/Library/Fonts/STHeiti Medium.ttc',
          ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    }
  });

  for (final viewport in const [
    ('mobile', Size(390, 844)),
    ('desktop', Size(1200, 800)),
  ]) {
    testWidgets('${viewport.$1}: clear setup, settings and local play', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = viewport.$2;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      SharedPreferences.setMockInitialValues({
        SharedPreferencesGameSettingsRepository.storageKey: const GameSettings(
          soundEnabled: false,
        ).encode(),
      });
      await tester.pumpWidget(
        const RepaintBoundary(key: ValueKey('product-review'), child: MyApp()),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DropdownButtonFormField<int>), findsNothing);
      await capture(tester, '${viewport.$1}-home');

      await tester.tap(find.text('人机对局'));
      await tester.pumpAndSettle();
      expect(find.text('和电脑下'), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
      await capture(tester, '${viewport.$1}-setup');
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.byType(ChessPage), findsNothing);

      await tester.tap(find.byTooltip('设置'));
      await tester.pumpAndSettle();
      await capture(tester, '${viewport.$1}-settings');
      if (viewport.$1 == 'desktop') {
        await tester.tap(find.text('电脑对手'));
        await tester.pumpAndSettle();
      } else {
        await tester.ensureVisible(find.text('高级电脑设置'));
        await tester.pumpAndSettle();
      }
      expect(find.byType(Slider), findsNothing);
      await capture(tester, '${viewport.$1}-computer-settings');
      await tester.tap(find.text('高级电脑设置'));
      await tester.pumpAndSettle();
      expect(find.byType(Slider), findsNWidgets(2));
      await tester.tap(find.byTooltip('返回对局'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('本地双人'));
      await tester.tap(find.text('本地双人'));
      await tester.pumpAndSettle();
      expect(find.text('电脑难度'), findsNothing);
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5 分钟'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '开始对局'));
      await tester.pumpAndSettle();
      expect(find.text('05:00'), findsNWidgets(2));
      await capture(tester, '${viewport.$1}-game');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
