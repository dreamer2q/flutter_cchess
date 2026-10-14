// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_cchess/help/help_pages.dart';
import 'package:flutter_cchess/main.dart';

void main() {
  testWidgets('renders the Chinese chess home page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('中国象棋'), findsOneWidget);
    expect(find.text('人机对局'), findsOneWidget);
    expect(find.text('本地双人'), findsOneWidget);
    expect(find.byKey(const ValueKey('ui-debug-toggle')), findsNothing);
  });

  testWidgets('home exposes rules help and about pages', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('象棋规则'));
    await tester.pumpAndSettle();
    expect(find.byType(XiangqiRulesPage), findsOneWidget);
    expect(find.text('七类棋子'), findsOneWidget);
    expect(find.textContaining('炮与目标之间必须恰好隔一个棋子'), findsOneWidget);

    await tester.tap(find.byTooltip('返回首页'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('关于中国象棋'));
    await tester.pumpAndSettle();
    expect(find.byType(AboutPage), findsOneWidget);
    expect(find.text('无需注册账号。对局记录与偏好设置仅保存在当前设备。'), findsOneWidget);
  });
}
