import 'package:beachiq/presentation/widgets/stat_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  group('StatTile', () {
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
          expect(find.bySemanticsLabel('Rain chance, 55%'), findsOneWidget);
        },
      );

      testWidgets('given no unit, renders only the value run', (tester) async {
        await tester.pumpWidget(
          wrap(
            const StatTile(
              icon: Icons.wb_sunny_outlined,
              label: 'UV index',
              value: '4.5',
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
                label: 'Current speed',
                value: 'No data',
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

    group('icon rotation', () {
      testWidgets('given no iconRotationDegrees, the icon is not rotated', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrap(
            const StatTile(
              icon: Icons.navigation,
              label: 'Wave direction',
              value: 'from NW',
            ),
          ),
        );

        final transform = tester.widget<Transform>(
          find.ancestor(
            of: find.byIcon(Icons.navigation),
            matching: find.byType(Transform),
          ),
        );
        // Matrix4.rotationZ(0) is the identity matrix.
        expect(transform.transform, Matrix4.identity());
      });

      testWidgets(
        'given an iconRotationDegrees, rotates the icon by that many degrees',
        (tester) async {
          await tester.pumpWidget(
            wrap(
              const StatTile(
                icon: Icons.navigation,
                label: 'Current direction',
                value: 'toward SE',
                iconRotationDegrees: 135,
              ),
            ),
          );

          final transform = tester.widget<Transform>(
            find.ancestor(
              of: find.byIcon(Icons.navigation),
              matching: find.byType(Transform),
            ),
          );
          expect(transform.transform, isNot(Matrix4.identity()));
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
                label: 'Current speed',
                value: '10',
                unit: 'km/h',
              ),
            ),
          );

          expect(tester.takeException(), isNull);
          // No stray empty placeholder chip: the only dot/circle-shaped
          // Container in the tree would belong to a status chip.
          final containers = tester.widgetList<Container>(
            find.byType(Container),
          );
          for (final container in containers) {
            final decoration = container.decoration;
            expect(
              decoration is BoxDecoration &&
                  decoration.shape == BoxShape.circle,
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
          ),
          throwsAssertionError,
        );
      });

      testWidgets(
        'given a long statusLabel (the Sea section\'s away-from-shore '
        'warning) at the real grid tile width, wraps onto further lines '
        'instead of being clipped',
        (tester) async {
          // Matches home_screen.dart's 360dp-wide device, 20px side
          // padding and StatTileGroup's 3-wide row with 12px gaps: the
          // exact width a real away-from-shore tile gets.
          const tileWidth = (360 - 40 - 24) / 3;

          await tester.pumpWidget(
            wrap(
              const SizedBox(
                width: tileWidth,
                child: StatTile(
                  icon: Icons.navigation,
                  label: 'Current direction',
                  value: 'toward E',
                  statusLabel: '(away from shore — stay close!)',
                  statusColor: Color(0xFFEF5350),
                  statusBold: true,
                ),
              ),
            ),
          );

          final statusText = tester.widget<Text>(
            find.text('(away from shore — stay close!)'),
          );
          // No `maxLines` cap at all — the text wraps onto as many lines
          // as it needs instead of ever being ellipsis-clipped.
          expect(statusText.maxLines, isNull);
          expect(statusText.overflow, isNot(TextOverflow.ellipsis));
          expect(statusText.style!.fontWeight, FontWeight.bold);
        },
      );
    });

    group('semantics', () {
      testWidgets(
        'given no status, exposes a single combined semantic label with '
        'label, value and unit',
        (tester) async {
          await tester.pumpWidget(
            wrap(
              const StatTile(
                icon: Icons.air,
                label: 'Wind',
                value: '12',
                unit: 'km/h',
              ),
            ),
          );

          expect(find.bySemanticsLabel('Wind, 12 km/h'), findsOneWidget);
        },
      );

      testWidgets('given a status, exposes a single combined semantic label '
          'with label, value, unit and status', (tester) async {
        await tester.pumpWidget(
          wrap(
            const StatTile(
              icon: Icons.air,
              label: 'Wind',
              value: '12',
              unit: 'km/h',
              statusLabel: 'Moderate',
              statusColor: Color(0xFFFFA726),
            ),
          ),
        );

        expect(
          find.bySemanticsLabel('Wind, 12 km/h, Moderate'),
          findsOneWidget,
        );
      });
    });

    group('no overflow at narrow width and large text scale', () {
      // Mirrors the real stat grid's own layout (home_screen.dart's
      // 20px-each-side padding, `StatTileGroup`'s 3-wide row with 12px
      // gaps) at a 360dp-wide device with a 1.3x text scale, the exact
      // combination issue #251's acceptance criterion names — rather than
      // an arbitrarily tiny box, so this reflects what a real device
      // actually gives each tile.
      Widget realisticRow(List<Widget> tiles) {
        assert(tiles.length == 3);
        return MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 800),
            textScaler: TextScaler.linear(1.3),
          ),
          child: MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: tiles[0]),
                    const SizedBox(width: 12),
                    Expanded(child: tiles[1]),
                    const SizedBox(width: 12),
                    Expanded(child: tiles[2]),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      testWidgets('given a long value, does not overflow or truncate the '
          'value', (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        // Longer than any real metric would produce, to stress the
        // FittedBox's shrink-to-fit rather than only the realistic case.
        const longValue = '<= 1234.5 m for 1234.5 m';

        await tester.pumpWidget(
          realisticRow(const [
            StatTile(
              icon: Icons.waves,
              label: 'Water depth',
              value: longValue,
              statusLabel: 'Steep',
              statusColor: Color(0xFFEF5350),
            ),
            SizedBox.shrink(),
            SizedBox.shrink(),
          ]),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        final richText = tester.widget<Text>(
          find.byKey(const Key('stat-tile-value')),
        );
        final spans = richText.textSpan! as TextSpan;
        expect(spans.toPlainText(), longValue);
        // No ellipsis/maxLines truncation on the value run itself — any
        // shrinking happens via the enclosing FittedBox's scale, not by
        // cutting characters.
        expect(richText.maxLines, isNull);
        expect(richText.overflow, isNot(TextOverflow.ellipsis));
      });

      testWidgets(
        "given the real 3x3 grid's nine tiles' worth of realistic content "
        '(across three rows), renders with no overflow',
        (tester) async {
          tester.view.physicalSize = const Size(360, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          final rows = [
            const [
              StatTile(icon: Icons.waves, label: 'Wave height', value: '0.9 m'),
              StatTile(
                icon: Icons.thermostat,
                label: 'Water temp',
                value: '24°C',
              ),
              StatTile(
                icon: Icons.waves,
                label: 'Water depth',
                value: '<= 1.2 m for 180 m',
                statusLabel: 'Gentle',
                statusColor: Color(0xFF2E7D32),
              ),
            ],
            const [
              StatTile(
                icon: Icons.speed,
                label: 'Current speed',
                value: '4 km/h',
              ),
              StatTile(
                icon: Icons.navigation,
                label: 'Current direction',
                value: 'toward SE',
                iconRotationDegrees: 135,
                statusLabel: '(away from shore — stay close!)',
                statusColor: Color(0xFFEF5350),
                statusBold: true,
              ),
              StatTile(
                icon: Icons.navigation,
                label: 'Wave direction',
                value: 'from NW',
                iconRotationDegrees: 315,
              ),
            ],
            const [
              StatTile(
                icon: Icons.air,
                label: 'Wind speed',
                value: '18',
                unit: 'km/h',
                statusLabel: 'Moderate',
                statusColor: Color(0xFFFFA726),
              ),
              StatTile(
                icon: Icons.water_drop_outlined,
                label: 'Rain chance',
                value: '80',
                unit: '%',
                statusLabel: 'High',
                statusColor: Color(0xFFEF5350),
              ),
              StatTile(
                icon: Icons.wb_sunny_outlined,
                label: 'UV index',
                value: '10.5',
                statusLabel: 'Very high',
                statusColor: Color(0xFFE53935),
              ),
            ],
          ];

          for (final row in rows) {
            await tester.pumpWidget(realisticRow(row));
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
          }
        },
      );
    });

    group('onTap', () {
      testWidgets('given no onTap, renders with no InkWell/tap target', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrap(
            const StatTile(
              icon: Icons.speed,
              label: 'Current speed',
              value: '10',
              unit: 'km/h',
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
              label: 'Current speed',
              value: '10',
              unit: 'km/h',
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

      testWidgets('given an onTap, still renders icon/label/value exactly '
          'like before', (tester) async {
        await tester.pumpWidget(
          wrap(
            StatTile(
              icon: Icons.speed,
              label: 'Current speed',
              value: '10',
              unit: 'km/h',
              onTap: () {},
            ),
          ),
        );

        expect(find.byIcon(Icons.speed), findsOneWidget);
        expect(find.text('Current speed'), findsOneWidget);
        expect(find.byKey(const Key('stat-tile-value')), findsOneWidget);
      });
    });
  });
}
