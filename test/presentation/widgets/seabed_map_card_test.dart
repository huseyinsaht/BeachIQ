import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:beachiq/data/services/seabed_map_repository.dart';
import 'package:beachiq/logic/unit_preferences.dart';
import 'package:beachiq/presentation/widgets/seabed_map_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY'
  '42YAAAAASUVORK5CYII=',
);

Future<SeabedMapRepository> _repo(
  Future<http.Response> Function(http.Request) handler,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return SeabedMapRepository(MockClient(handler), prefs);
}

Widget _wrap(Widget child, {double textScale = 1.0}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(360, 800),
      textScaler: TextScaler.linear(textScale),
    ),
    child: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    ),
  ),
);

void main() {
  group('SeabedMapCard', () {
    testWidgets('given a pending request, shows a same-size loading '
        'placeholder and the caveat', (tester) async {
      final completer = Completer<http.Response>();
      final repo = await _repo((_) => completer.future);

      await tester.pumpWidget(
        _wrap(
          SeabedMapCard(latitude: 38.32, longitude: 26.30, repository: repo),
        ),
      );

      expect(find.byKey(const Key('seabed-map-loading')), findsOneWidget);
      expect(find.byKey(const Key('seabed-map-image')), findsNothing);
      expect(find.byKey(const Key('seabed-map-caveat')), findsOneWidget);

      completer.complete(http.Response.bytes(_png, 200));
      await tester.pumpAndSettle();
    });

    testWidgets('given a PNG, shows the map with beach marker, scale bar, '
        'legend, attribution and the honest caveat', (tester) async {
      final repo = await _repo((_) async => http.Response.bytes(_png, 200));

      await tester.pumpWidget(
        _wrap(
          SeabedMapCard(latitude: 38.32, longitude: 26.30, repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('seabed-map-image')), findsOneWidget);
      expect(find.byKey(const Key('seabed-map-beach-marker')), findsOneWidget);
      expect(find.byKey(const Key('seabed-map-scale-bar')), findsOneWidget);
      expect(find.text('1 km'), findsOneWidget);
      expect(find.byKey(const Key('seabed-map-legend')), findsOneWidget);
      expect(find.text(seabedMapAttribution), findsOneWidget);
      expect(find.text(seabedMapCaveat), findsOneWidget);
      expect(find.byKey(const Key('seabed-map-no-data')), findsNothing);
    });

    testWidgets('given an imperial preference, labels the scale bar in miles', (
      tester,
    ) async {
      final repo = await _repo((_) async => http.Response.bytes(_png, 200));

      await tester.pumpWidget(
        _wrap(
          SeabedMapCard(
            latitude: 38.32,
            longitude: 26.30,
            repository: repo,
            unitSystem: UnitSystem.imperial,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0.5 mi'), findsOneWidget);
      expect(find.text('1 km'), findsNothing);
    });

    testWidgets('given a failed map request, shows "No seabed data" and no '
        'image', (tester) async {
      final repo = await _repo((_) async => http.Response('boom', 502));

      await tester.pumpWidget(
        _wrap(
          SeabedMapCard(latitude: 38.32, longitude: 26.30, repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('seabed-map-no-data')), findsOneWidget);
      expect(find.byKey(const Key('seabed-map-image')), findsNothing);
      expect(find.byKey(const Key('seabed-map-loading')), findsNothing);
      expect(find.byKey(const Key('seabed-map-caveat')), findsOneWidget);
    });

    testWidgets('given a map but a failed legend request, still shows the '
        'map without a legend', (tester) async {
      final repo = await _repo(
        (request) async =>
            request.url.queryParameters['request'] == 'GetLegendGraphic'
            ? http.Response('nope', 500)
            : http.Response.bytes(_png, 200),
      );

      await tester.pumpWidget(
        _wrap(
          SeabedMapCard(latitude: 38.32, longitude: 26.30, repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('seabed-map-image')), findsOneWidget);
      expect(find.byKey(const Key('seabed-map-legend')), findsNothing);
    });

    testWidgets('has no layout overflow at 360 dp with a large text scale', (
      tester,
    ) async {
      final repo = await _repo((_) async => http.Response.bytes(_png, 200));

      await tester.pumpWidget(
        _wrap(
          SeabedMapCard(latitude: 38.32, longitude: 26.30, repository: repo),
          textScale: 2.0,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('seabed-map-image')), findsOneWidget);
    });

    testWidgets('requests the map only once for a stable position', (
      tester,
    ) async {
      var mapRequests = 0;
      final repo = await _repo((request) async {
        if (request.url.queryParameters['request'] == 'GetMap') mapRequests++;
        return http.Response.bytes(_png, 200);
      });

      await tester.pumpWidget(
        _wrap(
          SeabedMapCard(latitude: 38.32, longitude: 26.30, repository: repo),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        _wrap(
          SeabedMapCard(latitude: 38.32, longitude: 26.30, repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(mapRequests, 1);
    });
  });
}
