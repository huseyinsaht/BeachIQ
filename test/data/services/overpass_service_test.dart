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
        'given a timeout then a success, query -> retries and succeeds on the second attempt',
        () async {
          final client = FakeHttpClient()
            ..queueResponse(
              host: 'overpass-api.de',
              body: 'ignored',
              delay: const Duration(milliseconds: 50),
              consumeOnce: true,
            )
            ..queueResponse(host: 'overpass-api.de', body: fixtureBody);
          final service = OverpassService(
            client,
            timeout: const Duration(milliseconds: 5),
            maxAttemptsPerEndpoint: 2,
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
        'given a response that decodes to a JSON array, query -> throws a descriptive exception',
        () async {
          final client = FakeHttpClient()
            ..queueResponse(host: 'overpass-api.de', body: '[1,2,3]');
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
                  contains('Unexpected Overpass response shape'),
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
          expect(
            client.requests.map((r) => r.url.toString()).toSet(),
            OverpassService.defaultEndpoints.toSet(),
          );
        },
      );

      group('hedged requests across mirrors', () {
        const third = 'https://overpass.private.coffee/api/interpreter';

        test(
          'given a hung primary and a working mirror, query -> answers from the '
          'mirror after the hedge delay, without waiting for the primary',
          () async {
            final client = FakeHttpClient()
              ..queueResponse(
                host: 'overpass-api.de',
                body: 'too late',
                delay: const Duration(seconds: 2),
              )
              ..queueResponse(host: 'overpass.kumi.systems', body: fixtureBody);
            final service = OverpassService(
              client,
              hedgeDelay: const Duration(milliseconds: 30),
              timeout: const Duration(seconds: 5),
            );

            final stopwatch = Stopwatch()..start();
            final result = await service.query('[out:json];node(1);out;');
            stopwatch.stop();

            expect(result, fixtureJson);
            expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)));
            expect(client.requests.map((r) => r.url.toString()), [
              _primary,
              _mirror,
            ]);
          },
        );

        test(
          'given the primary answers quickly, query -> never contacts the other '
          'mirrors',
          () async {
            final client = FakeHttpClient()
              ..queueResponse(host: 'overpass-api.de', body: fixtureBody);
            final service = OverpassService(
              client,
              hedgeDelay: const Duration(milliseconds: 200),
            );

            await service.query('[out:json];node(1);out;');
            await Future<void>.delayed(const Duration(milliseconds: 300));

            expect(client.requests.map((r) => r.url.toString()), [_primary]);
          },
        );

        test(
          'given the primary fails right away, query -> starts the next mirror '
          'immediately instead of waiting for the hedge delay',
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
              hedgeDelay: const Duration(seconds: 30),
            );

            final stopwatch = Stopwatch()..start();
            final result = await service.query('[out:json];node(1);out;');
            stopwatch.stop();

            expect(result, fixtureJson);
            expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
          },
        );

        test(
          'given the first two mirrors fail, query -> the third one answers',
          () async {
            final client = FakeHttpClient()
              ..queueResponse(
                host: 'overpass-api.de',
                body: 'down',
                statusCode: 503,
              )
              ..queueResponse(
                host: 'overpass.kumi.systems',
                body: 'down',
                statusCode: 503,
              )
              ..queueResponse(
                host: 'overpass.private.coffee',
                body: fixtureBody,
              );
            final service = OverpassService(
              client,
              hedgeDelay: const Duration(seconds: 30),
            );

            final result = await service.query('[out:json];node(1);out;');

            expect(result, fixtureJson);
            expect(client.requests.last.url.toString(), third);
          },
        );

        test(
          'given no endpoint answers before the overall timeout, query -> throws '
          'a descriptive exception without waiting for each request',
          () async {
            final client = FakeHttpClient()
              ..queueResponse(
                matcher: (r) => true,
                body: fixtureBody,
                delay: const Duration(seconds: 3),
              );
            final service = OverpassService(
              client,
              hedgeDelay: const Duration(milliseconds: 10),
              timeout: const Duration(seconds: 10),
              overallTimeout: const Duration(milliseconds: 150),
            );

            final stopwatch = Stopwatch()..start();
            await expectLater(
              () => service.query('[out:json];node(1);out;'),
              throwsA(
                isA<Exception>().having(
                  (e) => e.toString(),
                  'message',
                  contains('no endpoint answered within'),
                ),
              ),
            );
            stopwatch.stop();

            expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
          },
        );

        test(
          'given every endpoint fails, query -> the message lists each one',
          () async {
            final client = FakeHttpClient()
              ..queueResponse(
                matcher: (r) => true,
                body: 'down',
                statusCode: 503,
              );
            final service = OverpassService(
              client,
              hedgeDelay: const Duration(milliseconds: 5),
            );

            await expectLater(
              () => service.query('[out:json];node(1);out;'),
              throwsA(
                isA<Exception>().having(
                  (e) => e.toString(),
                  'message',
                  allOf([
                    contains(
                      'failed on all ${OverpassService.defaultEndpoints.length}',
                    ),
                    for (final endpoint in OverpassService.defaultEndpoints)
                      contains(endpoint),
                  ]),
                ),
              ),
            );
          },
        );

        test('defaultEndpoints has several distinct mirrors', () {
          expect(
            OverpassService.defaultEndpoints.length,
            greaterThanOrEqualTo(3),
          );
          expect(
            OverpassService.defaultEndpoints.toSet(),
            hasLength(OverpassService.defaultEndpoints.length),
          );
        });
      });
    });
  });
}
