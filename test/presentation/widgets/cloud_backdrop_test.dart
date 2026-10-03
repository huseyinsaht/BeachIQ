import 'dart:ui' as ui;

import 'package:beachiq/presentation/widgets/cloud_backdrop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  group('CloudBackdrop', () {
    testWidgets('renders a CustomPaint driven by CloudBackdropPainter', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const CloudBackdrop()));

      final customPaint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(CloudBackdrop),
          matching: find.byType(CustomPaint),
        ),
      );
      expect(customPaint.painter, isA<CloudBackdropPainter>());
    });

    testWidgets('is wrapped in IgnorePointer so it never intercepts taps', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const CloudBackdrop()));

      final ignorePointer = tester.widget<IgnorePointer>(
        find.descendant(
          of: find.byType(CloudBackdrop),
          matching: find.byType(IgnorePointer),
        ),
      );
      expect(ignorePointer.ignoring, isTrue);
    });

    testWidgets('is wrapped in a RepaintBoundary', (tester) async {
      await tester.pumpWidget(wrap(const CloudBackdrop()));

      expect(
        find.descendant(
          of: find.byType(CloudBackdrop),
          matching: find.byType(RepaintBoundary),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'given a button geometrically beneath it, a tap still reaches the '
      'button (hit-testing is not blocked)',
      (tester) async {
        var tapped = false;

        // The backdrop is stacked directly on top of the button, covering
        // exactly the same area a real screen would place it over (the
        // header, top-right) — without IgnorePointer this tap would be
        // swallowed by the backdrop's own CustomPaint instead of reaching
        // the button beneath it.
        await tester.pumpWidget(
          wrap(
            Stack(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: SizedBox(
                    width: 260,
                    height: 200,
                    child: ElevatedButton(
                      onPressed: () => tapped = true,
                      child: const Text('Beneath'),
                    ),
                  ),
                ),
                const Align(
                  alignment: Alignment.topRight,
                  child: CloudBackdrop(),
                ),
              ],
            ),
          ),
        );

        await tester.tap(find.text('Beneath'));
        await tester.pump();

        expect(tapped, isTrue);
      },
    );

    testWidgets('rejects an opacity outside the 0.08-0.15 design range', (
      tester,
    ) async {
      expect(() => CloudBackdrop(opacity: 0.5), throwsAssertionError);
      expect(() => CloudBackdrop(opacity: 0), throwsAssertionError);
    });

    test('defaults to an opacity within the faint 0.08-0.15 design range', () {
      const backdrop = CloudBackdrop();
      expect(backdrop.opacity, inInclusiveRange(0.08, 0.15));
    });
  });

  group('CloudBackdropPainter', () {
    test('shouldRepaint is false for an unchanged opacity (deterministic, '
        'no needless repaints while the screen scrolls)', () {
      const painter = CloudBackdropPainter(opacity: 0.12);
      const sameOpacity = CloudBackdropPainter(opacity: 0.12);

      expect(painter.shouldRepaint(sameOpacity), isFalse);
    });

    test('shouldRepaint is true when opacity changes', () {
      const painter = CloudBackdropPainter(opacity: 0.12);
      const differentOpacity = CloudBackdropPainter(opacity: 0.08);

      expect(painter.shouldRepaint(differentOpacity), isTrue);
    });

    test('paint is a pure function of size/opacity: never throws for a '
        'zero or tiny size, so a first layout frame at Size.zero is safe', () {
      const painter = CloudBackdropPainter(opacity: 0.12);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      expect(() => painter.paint(canvas, Size.zero), returnsNormally);
      expect(
        () => painter.paint(canvas, const Size(260, 200)),
        returnsNormally,
      );
      recorder.endRecording();
    });

    test(
      'a zero opacity paints nothing (no exception, no-op early return)',
      () {
        const painter = CloudBackdropPainter(opacity: 0);
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);

        expect(
          () => painter.paint(canvas, const Size(260, 200)),
          returnsNormally,
        );
        recorder.endRecording();
      },
    );
  });
}
