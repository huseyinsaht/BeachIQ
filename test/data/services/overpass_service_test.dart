import 'dart:convert';
import 'dart:io';

import 'package:beachiq/data/services/overpass_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

const _primary = 'https://overpass-api.de/api/interpreter';
const _mirror = 'https://overpass.kumi.systems/api/interpreter';

String _loadFixture() {
  return File('test/fixtures/overpass_beaches_response.json').readAsStringSync();
}

/// A fake [http.Client] whose response is produced by a callback, so each
/// test controls exactly what comes back without touching the network.
class _FakeClient extends http.BaseClient {
  _FakeClient(this._handler);

  final Future<http.Response> Function(http.Request request) _handler;
  int callCount = 0;
  final List<Uri> requestedUrls = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    callCount++;
    final req = request as http.Request;
    requestedUrls.add(req.url);
    final response = await _handler(req);
    return http.StreamedResponse(
      Stream.value(utf8.encode(response.body)),
      response.statusCode,
      headers: response.headers,
    );
  }
}

void main() {
  final fixtureBody = _loadFixture();
  final fixtureJson = json.decode(fixtureBody) as Map<String, dynamic>;

  group('OverpassService.query', () {
    test('parses a successful response into the raw decoded structure', () async {
      final client = _FakeClient((request) async {
        return http.Response(fixtureBody, 200);
      });
      final service = OverpassService(client);

      final result = await service.query('[out:json];node(1);out;');

      expect(result, fixtureJson);
      expect((result['elements'] as List).length, 5);
      expect(client.callCount, 1);
    });

    test('sends a User-Agent header identifying the app', () async {
      http.Request? captured;
      final client = _FakeClient((request) async {
        captured = request;
        return http.Response(fixtureBody, 200);
      });
      final service = OverpassService(client);

      await service.query('[out:json];node(1);out;');

      expect(captured!.headers['User-Agent'], isNotNull);
      expect(captured!.headers['User-Agent'], contains('BeachIQ'));
    });

    test('retries after a 429 and succeeds on the second attempt', () async {
      var attempt = 0;
      final client = _FakeClient((request) async {
        attempt++;
        if (attempt == 1) {
          return http.Response('Too Many Requests', 429);
        }
        return http.Response(fixtureBody, 200);
      });
      final service = OverpassService(client, initialBackoff: const Duration(milliseconds: 1));

      final result = await service.query('[out:json];node(1);out;');

      expect(result, fixtureJson);
      expect(client.callCount, 2);
      expect(client.requestedUrls.every((u) => u.toString() == _primary), isTrue);
    });

    test('falls back to the mirror endpoint when the primary keeps failing', () async {
      final client = _FakeClient((request) async {
        if (request.url.toString() == _primary) {
          return http.Response('Internal Server Error', 500);
        }
        return http.Response(fixtureBody, 200);
      });
      final service = OverpassService(client, initialBackoff: const Duration(milliseconds: 1));

      final result = await service.query('[out:json];node(1);out;');

      expect(result, fixtureJson);
      expect(client.requestedUrls.last.toString(), _mirror);
      expect(client.requestedUrls.any((u) => u.toString() == _primary), isTrue);
    });

    test('de-duplicates two concurrent calls with the same query', () async {
      final client = _FakeClient((request) async {
        await Future.delayed(const Duration(milliseconds: 20));
        return http.Response(fixtureBody, 200);
      });
      final service = OverpassService(client);

      final results = await Future.wait([
        service.query('[out:json];node(1);out;'),
        service.query('[out:json];node(1);out;'),
      ]);

      expect(results[0], fixtureJson);
      expect(results[1], fixtureJson);
      expect(client.callCount, 1);
    });

    test('throws a descriptive exception when a request times out on every endpoint', () async {
      final client = _FakeClient((request) async {
        await Future.delayed(const Duration(milliseconds: 50));
        return http.Response(fixtureBody, 200);
      });
      final service = OverpassService(
        client,
        timeout: const Duration(milliseconds: 5),
        maxAttemptsPerEndpoint: 1,
        initialBackoff: const Duration(milliseconds: 1),
      );

      await expectLater(
        () => service.query('[out:json];node(1);out;'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            allOf(contains('Overpass request failed'), contains('Timed out')),
          ),
        ),
      );
    });

    test('throws a descriptive exception on malformed JSON', () async {
      final client = _FakeClient((request) async {
        return http.Response('not valid json {', 200);
      });
      final service = OverpassService(client, initialBackoff: const Duration(milliseconds: 1));

      await expectLater(
        () => service.query('[out:json];node(1);out;'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            allOf(contains('Overpass request failed'), contains('Malformed Overpass JSON')),
          ),
        ),
      );
    });

    test('throws a descriptive exception when both endpoints return non-200', () async {
      final client = _FakeClient((request) async {
        return http.Response('Service Unavailable', 503);
      });
      final service = OverpassService(client, initialBackoff: const Duration(milliseconds: 1));

      await expectLater(
        () => service.query('[out:json];node(1);out;'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            allOf(contains('Overpass request failed'), contains('HTTP 503')),
          ),
        ),
      );
      expect(client.requestedUrls.map((u) => u.toString()).toSet(), {_primary, _mirror});
    });
  });
}
