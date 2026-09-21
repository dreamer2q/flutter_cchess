// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_cchess/main.dart';

void main() {
  testWidgets('renders the Chinese chess home page', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Chinses Chess'), findsOneWidget);
    expect(find.text('人机对局'), findsOneWidget);
  });
}
