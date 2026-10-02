import 'package:beachiq/data/services/overpass_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_http_client.dart';
import '../../helpers/fixtures.dart';

const _primary = 'https://overpass-api.de/api/interpreter';
const _mirror = 'https://overpass.kumi.systems/api/interpreter';

void main() {
  final fixtureBody = loadFixtureString('overpass_beaches_response.json');
  final fixtureJson = loadFixtureJson('overpass_beaches_response.json');

  group('OverpassService', () {
    group('query', () {
      test(
        'given a successful response, query -> resolves to the raw decoded structure',
        () async {
          final client = FakeHttpClient()
            ..queueResponse(host: 'overpass-api.de', body: fixtureBody);
          final service = OverpassService(client);

          final result = await service.query('[out:json];node(1);out;');

          expect(result, fixtureJson);
          expect((result['elements'] as List).length, 5);
          expect(client.requests, hasLength(1));
        },
      );

      test(
        'given a successful response, query -> sends a User-Agent header identifying the app',
        () async {
          final client = FakeHttpClient()
            ..queueResponse(host: 'overpass-api.de', body: fixtureBody);
          final service = OverpassService(client);

          await service.query('[out:json];node(1);out;');

          final userAgent = client.requests.single.headers['User-Agent'];
          expect(userAgent, isNotNull);
          expect(userAgent, contains('BeachIQ'));
        },
      );

      test(
        'given a 429 then a success, query -> retries and succeeds on the second attempt',
        () async {
          final client = FakeHttpClient()
            ..queueResponse(
              host: 'overpass-api.de',
              body: 'Too Many Requests',
              statusCode: 429,
              consumeOnce: true,
            )
            ..queueResponse(host: 'overpass-api.de', body: fixtureBody);
          final service = OverpassService(
            client,
            initialBackoff: const Duration(milliseconds: 1),
          );

          final result = await service.query('[out:json];node(1);out;');

          expect(result, fixtureJson);
          expect(client.requests, hasLength(2));
          expect(
            client.requests.every((r) => r.url.toString() == _primary),
            isTrue,
          );
        },
      );

      test(
        'given the primary endpoint keeps failing, query -> falls back to the mirror endpoint',
        () async {
          final client = FakeHttpClient()
            ..queueResponse(
              host: 'overpass-api.de',
              body: 'Internal Server Error',
              statusCode: 500,
            )
            ..queueResponse(host: 'overpass.kumi.systems', body: fixtureBody);
          final service = OverpassService(
            client,
            initialBackoff: const Duration(milliseconds: 1),
          );

          final result = await service.query('[out:json];node(1);out;');

          expect(result, fixtureJson);
          expect(client.requests.last.url.toString(), _mirror);
          expect(
            client.requests.any((r) => r.url.toString() == _primary),
            isTrue,
          );
        },
      );

      test(
        'given two concurrent calls with the same query, query -> de-duplicates into a single request',
        () async {
          final client = FakeHttpClient()
            ..queueResponse(matcher: (r) => true, body: fixtureBody);
          final service = OverpassService(client);

          final results = await Future.wait([
            service.query('[out:json];node(1);out;'),
            service.query('[out:json];node(1);out;'),
          ]);

          expect(results[0], fixtureJson);
          expect(results[1], fixtureJson);
          expect(client.requests, hasLength(1));
        },
      );

      test(
        'given every endpoint times out, query -> throws a descriptive exception',
        () async {
          final client = FakeHttpClient()
            ..queueResponse(
              matcher: (r) => true,
              body: fixtureBody,
              delay: const Duration(milliseconds: 50),
            );
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
                allOf(
                  contains('Overpass request failed'),
                  contains('Timed out'),
                ),
              ),
            ),
          );
        },
      );

      test(
        'given malformed JSON, query -> throws a descriptive exception',
        () async {
          final client = FakeHttpClient()
            ..queueResponse(host: 'overpass-api.de', body: 'not valid json {');
          final service = OverpassService(
            client,
            initialBackoff: const Duration(milliseconds: 1),
          );

          await expectLater(
            () => service.query('[out:json];node(1);out;'),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                allOf(
                  contains('Overpass request failed'),
                  contains('Malformed Overpass JSON'),
                ),
              ),
            ),
          );
        },
      );

      test(
        'given both endpoints return non-200, query -> throws a descriptive exception',
        () async {
          final client = FakeHttpClient()
            ..queueResponse(
              matcher: (r) => true,
              body: 'Service Unavailable',
              statusCode: 503,
            );
          final service = OverpassService(
            client,
            initialBackoff: const Duration(milliseconds: 1),
          );

          await expectLater(
            () => service.query('[out:json];node(1);out;'),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                allOf(
                  contains('Overpass request failed'),
                  contains('HTTP 503'),
                ),
              ),
            ),
          );
          expect(client.requests.map((r) => r.url.toString()).toSet(), {
            _primary,
            _mirror,
          });
        },
      );
    });
  });
}
