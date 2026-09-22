import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cchess/chess/theme/motion_spec.dart';
import 'package:flutter_cchess/chess/widget/animated_invalid_move.dart';
import 'package:flutter_cchess/chess/widget/animated_move.dart';
import 'package:flutter_cchess/chess/widget/animated_overlay.dart';

void main() {
  testWidgets('MotionSpec disables duration when reduced motion is requested',
      (tester) async {
    Duration? effectiveDuration;

    await tester.pumpWidget(_host(
      disableAnimations: true,
      child: Builder(
        builder: (context) {
          effectiveDuration =
              MotionSpec.durationOf(context, MotionSpec.legalMove);
          return const SizedBox();
        },
      ),
    ));

    expect(effectiveDuration, Duration.zero);
  });

  testWidgets('legal move uses the shared timing and reaches its destination',
      (tester) async {
    var ended = 0;
    const begin = Alignment(-1, 0);
    const end = Alignment(1, 0);

    await tester.pumpWidget(_host(
      child: AnimatedMove(
        begin: begin,
        end: end,
        onEnd: () => ended++,
        child: const SizedBox.square(dimension: 20),
      ),
    ));
    expect(_moveAlignment(tester), begin);

    await tester.pump(const Duration(milliseconds: 110));
    final halfway = _moveAlignment(tester);
    expect(halfway.x, greaterThan(begin.x));
    expect(halfway.x, lessThan(end.x));

    await tester.pump(const Duration(milliseconds: 110));
    await tester.pump(const Duration(milliseconds: 1));
    expect(_moveAlignment(tester), end);
    expect(ended, 1);
  });

  testWidgets('reduced motion completes a legal move without interpolation',
      (tester) async {
    var ended = 0;

    await tester.pumpWidget(_host(
      disableAnimations: true,
      child: AnimatedMove(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        onEnd: () => ended++,
        child: const SizedBox.square(dimension: 20),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 1));

    expect(_moveAlignment(tester), Alignment.bottomRight);
    expect(ended, 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('invalid move shakes at its source instead of crossing the board',
      (tester) async {
    var ended = 0;
    const begin = Alignment(-.8, .5);

    await tester.pumpWidget(_host(
      child: AnimatedInvalidMove(
        begin: begin,
        end: const Alignment(.9, -.7),
        onEnd: () => ended++,
        child: const SizedBox.square(dimension: 20),
      ),
    ));

    await tester.pump(const Duration(milliseconds: 36));
    expect(_invalidAlignment(tester), begin);
    final offset = _invalidTransform(tester).transform.getTranslation();
    expect(offset.x.abs(), closeTo(MotionSpec.invalidShakeDistance, .01));
    expect(offset.y, 0);

    await tester.pump(const Duration(milliseconds: 144));
    await tester.pump(const Duration(milliseconds: 1));
    expect(_invalidAlignment(tester), begin);
    expect(_invalidTransform(tester).transform.getTranslation().x,
        closeTo(0, .01));
    expect(ended, 1);
  });

  testWidgets('reduced motion keeps an invalid move stationary',
      (tester) async {
    var ended = 0;

    await tester.pumpWidget(_host(
      disableAnimations: true,
      child: AnimatedInvalidMove(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        onEnd: () => ended++,
        child: const SizedBox.square(dimension: 20),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 1));

    expect(_invalidAlignment(tester), Alignment.centerLeft);
    expect(_invalidTransform(tester).transform.getTranslation().x, 0);
    expect(ended, 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('overlay fades, scales, completes once, and disposes cleanly',
      (tester) async {
    var ended = 0;

    await tester.pumpWidget(_host(
      child: AnimatedOverlay(
        duration: const Duration(milliseconds: 200),
        onEnd: () => ended++,
        child: const Text('将军'),
      ),
    ));

    final fade = tester.widget<FadeTransition>(
      find.descendant(
        of: find.byType(AnimatedOverlay),
        matching: find.byType(FadeTransition),
      ),
    );
    final scale = tester.widget<ScaleTransition>(
      find.descendant(
        of: find.byType(AnimatedOverlay),
        matching: find.byType(ScaleTransition),
      ),
    );
    expect(fade.opacity.value, 0);
    expect(scale.scale.value, closeTo(.94, .001));

    await tester.pump(const Duration(milliseconds: 50));
    expect(fade.opacity.value, closeTo(1, .001));
    expect(scale.scale.value, greaterThan(.94));

    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 1));
    expect(fade.opacity.value, 0);
    expect(ended, 1);

    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion overlay finishes without a running ticker',
      (tester) async {
    var ended = 0;

    await tester.pumpWidget(_host(
      disableAnimations: true,
      child: AnimatedOverlay(
        onEnd: () => ended++,
        child: const Text('绝杀'),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 1));

    expect(ended, 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}

Widget _host({required Widget child, bool disableAnimations = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(
        body: SizedBox(width: 300, height: 300, child: child),
      ),
    ),
  );
}

Alignment _moveAlignment(WidgetTester tester) => tester
    .widget<Align>(
      find.descendant(
        of: find.byType(AnimatedMove),
        matching: find.byType(Align),
      ),
    )
    .alignment as Alignment;

Alignment _invalidAlignment(WidgetTester tester) => tester
    .widget<Align>(
      find.descendant(
        of: find.byType(AnimatedInvalidMove),
        matching: find.byType(Align),
      ),
    )
    .alignment as Alignment;

Transform _invalidTransform(WidgetTester tester) => tester.widget<Transform>(
      find.descendant(
        of: find.byType(AnimatedInvalidMove),
        matching: find.byType(Transform),
      ),
    );
