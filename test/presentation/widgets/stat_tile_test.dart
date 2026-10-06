import 'package:beachiq/presentation/widgets/stat_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  group('value and unit', () {
    testWidgets(
      'given a value and a unit, renders them as separate text runs',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            const StatTile(
              icon: Icons.air,
              label: 'Wind speed',
              value: '18',
              unit: 'km/h',
              trendDirection: StatTrendDirection.up,
              trendDelta: '2 km/h',
            ),
          ),
        );

        final richText = tester.widget<Text>(
          find.byKey(const Key('stat-tile-value')),
        );
        final spans = richText.textSpan! as TextSpan;
        final children = spans.children!.cast<TextSpan>();

        expect(children, hasLength(2));
        expect(children[0].text, '18');
        expect(children[1].text, ' km/h');
        // The unit is a visually smaller, secondary run, not merely a
        // continuation of the value's own style.
        expect(
          children[1].style!.fontSize,
          lessThan(children[0].style!.fontSize!),
        );
        // Never concatenated into a single plain string.
        expect(spans.toPlainText(), '18 km/h');
      },
    );

    testWidgets(
      'given a percent unit, attaches it directly with no leading space '
      '(unlike a word unit such as "km/h")',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            const StatTile(
              icon: Icons.water_drop_outlined,
              label: 'Rain chance',
              value: '55',
              unit: '%',
              trendDirection: StatTrendDirection.up,
              trendDelta: '3%',
            ),
          ),
        );

        final richText = tester.widget<Text>(
          find.byKey(const Key('stat-tile-value')),
        );
        final spans = richText.textSpan! as TextSpan;
        final children = spans.children!.cast<TextSpan>();

        expect(children[1].text, '%');
        expect(spans.toPlainText(), '55%');
        expect(
          find.bySemanticsLabel('Rain chance, 55%, trend up 3%'),
          findsOneWidget,
        );
      },
    );

    testWidgets('given no unit, renders only the value run', (tester) async {
      await tester.pumpWidget(
        wrap(
          const StatTile(
            icon: Icons.wb_sunny_outlined,
            label: 'UV index',
            value: '4.5',
            trendDirection: StatTrendDirection.up,
            trendDelta: '0.5',
          ),
        ),
      );

      final richText = tester.widget<Text>(
        find.byKey(const Key('stat-tile-value')),
      );
      final spans = richText.textSpan! as TextSpan;
      final children = spans.children!.cast<TextSpan>();

      expect(children, hasLength(1));
      expect(children.single.text, '4.5');
    });

    testWidgets('renders icon and label', (tester) async {
      await tester.pumpWidget(
        wrap(
          const StatTile(
            icon: Icons.air,
            label: 'Wind speed',
            value: '18',
            unit: 'km/h',
            trendDirection: StatTrendDirection.up,
            trendDelta: '2 km/h',
          ),
        ),
      );

      expect(find.byIcon(Icons.air), findsOneWidget);
      expect(find.text('Wind speed'), findsOneWidget);
    });

    testWidgets(
      'given a null-data placeholder value, renders it with no unit',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            const StatTile(
              icon: Icons.speed,
              label: 'Pressure',
              value: 'No data',
              trendDirection: StatTrendDirection.up,
              trendDelta: '1 hPa',
            ),
          ),
        );

        final richText = tester.widget<Text>(
          find.byKey(const Key('stat-tile-value')),
        );
        final spans = richText.textSpan! as TextSpan;
        final children = spans.children!.cast<TextSpan>();
        expect(children, hasLength(1));
        expect(children.single.text, 'No data');
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('status', () {
    testWidgets('given a statusLabel and statusColor, renders a colored '
        'status word', (tester) async {
      const statusColor = Color(0xFF2E7D32);

      await tester.pumpWidget(
        wrap(
          const StatTile(
            icon: Icons.air,
            label: 'Wind speed',
            value: '10',
            unit: 'km/h',
            statusLabel: 'Calm',
            statusColor: statusColor,
            trendDirection: StatTrendDirection.up,
            trendDelta: '2 km/h',
          ),
        ),
      );

      final statusText = tester.widget<Text>(find.text('Calm'));
      expect(statusText.style!.color, statusColor);
    });

    testWidgets(
      'given no statusLabel, renders no status chip and does not crash',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            const StatTile(
              icon: Icons.speed,
              label: 'Pressure',
              value: '1013',
              unit: 'hPa',
              trendDirection: StatTrendDirection.up,
              trendDelta: '1 hPa',
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        // No stray empty placeholder chip: the only dot/circle-shaped
        // Container in the tree would belong to a status chip.
        final containers = tester.widgetList<Container>(find.byType(Container));
        for (final container in containers) {
          final decoration = container.decoration;
          expect(
            decoration is BoxDecoration && decoration.shape == BoxShape.circle,
            isFalse,
          );
        }
      },
    );

    testWidgets('given statusLabel without statusColor, asserts rather than '
        'rendering an uncolored chip', (tester) async {
      expect(
        () => StatTile(
          icon: Icons.air,
          label: 'Wind speed',
          value: '10',
          statusLabel: 'Calm',
          trendDirection: StatTrendDirection.up,
          trendDelta: '2 km/h',
        ),
        throwsAssertionError,
      );
    });
  });

  group('trend', () {
    testWidgets('renders an up trend indicator', (tester) async {
      await tester.pumpWidget(
        wrap(
          const StatTile(
            icon: Icons.water_drop,
            label: 'Rain chance',
            value: '20',
            unit: '%',
            trendDirection: StatTrendDirection.up,
            trendDelta: '5%',
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_drop_up), findsOneWidget);
      expect(find.byIcon(Icons.arrow_drop_down), findsNothing);
    });

    testWidgets('renders a down trend indicator', (tester) async {
      await tester.pumpWidget(
        wrap(
          const StatTile(
            icon: Icons.speed,
            label: 'Pressure',
            value: '1013',
            unit: 'hPa',
            trendDirection: StatTrendDirection.down,
            trendDelta: '3 hPa',
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
      expect(find.byIcon(Icons.arrow_drop_up), findsNothing);
      expect(find.text('3 hPa'), findsOneWidget);
    });
  });

  group('semantics', () {
    testWidgets(
      'given no status, exposes a single combined semantic label with '
      'label, value, unit and trend',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            const StatTile(
              icon: Icons.air,
              label: 'Wind',
              value: '12',
              unit: 'km/h',
              trendDirection: StatTrendDirection.up,
              trendDelta: '2%',
            ),
          ),
        );

        expect(
          find.bySemanticsLabel('Wind, 12 km/h, trend up 2%'),
          findsOneWidget,
        );
      },
    );

    testWidgets('given a status, exposes a single combined semantic label with '
        'label, value, unit, status and trend', (tester) async {
      await tester.pumpWidget(
        wrap(
          const StatTile(
            icon: Icons.air,
            label: 'Wind',
            value: '12',
            unit: 'km/h',
            statusLabel: 'Moderate',
            statusColor: Color(0xFFFFA726),
            trendDirection: StatTrendDirection.up,
            trendDelta: '2%',
          ),
        ),
      );

      expect(
        find.bySemanticsLabel('Wind, 12 km/h, Moderate, trend up 2%'),
        findsOneWidget,
      );
    });
  });

  group('no overflow at narrow width and large text scale', () {
    // Mirrors the real stat grid's own layout
    // (home_screen.dart's 20px-each-side padding, 2 columns, 16px
    // spacing, childAspectRatio 1.5) at a 360dp-wide device with a 1.3x
    // text scale, the exact combination issue #215's acceptance
    // criterion names — rather than an arbitrarily tiny box, so this
    // reflects what a real device actually gives each tile.
    Widget realisticGrid(List<Widget> tiles) {
      return MediaQuery(
        data: const MediaQueryData(
          size: Size(360, 800),
          textScaler: TextScaler.linear(1.3),
        ),
        child: MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.5,
                children: tiles,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('given a long value, does not overflow or truncate the value', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Longer than any real metric would produce, to stress the
      // FittedBox's shrink-to-fit rather than only the realistic case.
      const longValue = '1234.5';

      await tester.pumpWidget(
        realisticGrid(const [
          StatTile(
            icon: Icons.speed,
            label: 'Pressure',
            value: longValue,
            unit: 'hPa',
            statusLabel: 'Falling fast',
            statusColor: Color(0xFFEF5350),
            trendDirection: StatTrendDirection.down,
            trendDelta: '3 hPa',
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final richText = tester.widget<Text>(
        find.byKey(const Key('stat-tile-value')),
      );
      final spans = richText.textSpan! as TextSpan;
      expect(spans.toPlainText(), '$longValue hPa');
      // No ellipsis/maxLines truncation on the value run itself — any
      // shrinking happens via the enclosing FittedBox's scale, not by
      // cutting characters.
      expect(richText.maxLines, isNull);
      expect(richText.overflow, isNot(TextOverflow.ellipsis));
    });

    testWidgets("given the real stat grid's four tiles with realistic content, "
        'renders with no overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        realisticGrid(const [
          StatTile(
            icon: Icons.air,
            label: 'Wind speed',
            value: '18',
            unit: 'km/h',
            statusLabel: 'Moderate',
            statusColor: Color(0xFFFFA726),
            trendDirection: StatTrendDirection.up,
            trendDelta: '2 km/h',
          ),
          StatTile(
            icon: Icons.water_drop_outlined,
            label: 'Rain chance',
            value: 'No data',
            statusLabel: 'Low',
            statusColor: Color(0xFF2E7D32),
            trendDirection: StatTrendDirection.down,
            trendDelta: '3%',
          ),
          StatTile(
            icon: Icons.speed,
            label: 'Pressure',
            value: '1013',
            unit: 'hPa',
            trendDirection: StatTrendDirection.up,
            trendDelta: '1 hPa',
          ),
          StatTile(
            icon: Icons.wb_sunny_outlined,
            label: 'UV index',
            value: '10.5',
            statusLabel: 'Very high',
            statusColor: Color(0xFFE53935),
            trendDirection: StatTrendDirection.up,
            trendDelta: '0.5',
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('onTap', () {
    testWidgets('given no onTap, renders with no InkWell/tap target', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const StatTile(
            icon: Icons.speed,
            label: 'Pressure',
            value: '1013',
            unit: 'hPa',
            trendDirection: StatTrendDirection.up,
            trendDelta: '1 hPa',
          ),
        ),
      );

      expect(find.byKey(const Key('stat-tile-tap-target')), findsNothing);
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('given an onTap, wraps the tile in an InkWell and invokes '
        'it on tap', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        wrap(
          StatTile(
            icon: Icons.speed,
            label: 'Pressure',
            value: '1013',
            unit: 'hPa',
            trendDirection: StatTrendDirection.up,
            trendDelta: '1 hPa',
            onTap: () => tapped = true,
          ),
        ),
      );

      expect(find.byKey(const Key('stat-tile-tap-target')), findsOneWidget);
      expect(find.byType(InkWell), findsOneWidget);

      await tester.tap(find.byKey(const Key('stat-tile-tap-target')));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('given an onTap, still renders icon/label/value/trend '
        'exactly like before', (tester) async {
      await tester.pumpWidget(
        wrap(
          StatTile(
            icon: Icons.speed,
            label: 'Pressure',
            value: '1013',
            unit: 'hPa',
            trendDirection: StatTrendDirection.down,
            trendDelta: '2 hPa',
            onTap: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.speed), findsOneWidget);
      expect(find.text('Pressure'), findsOneWidget);
      expect(find.byKey(const Key('stat-tile-value')), findsOneWidget);
      expect(find.text('2 hPa'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
    });
  });
}
