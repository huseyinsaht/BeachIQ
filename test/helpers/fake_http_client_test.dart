import 'package:flutter_test/flutter_test.dart';

import 'fake_http_client.dart';

void main() {
  group('FakeHttpClient', () {
    test(
      'given a queued response, send -> replays its body and status',
      () async {
        final client = FakeHttpClient();
        client.queueResponse(
          host: 'example.com',
          body: 'hello',
          statusCode: 201,
        );

        final response = await client.get(
          Uri.parse('https://example.com/path'),
        );

        expect(response.statusCode, 201);
        expect(response.body, 'hello');
      },
    );

    test(
      'given queueJson, send -> replays a JSON-encoded body with the content-type header',
      () async {
        final client = FakeHttpClient();
        client.queueJson(host: 'example.com', json: {'wave_height': 1.2});

        final response = await client.get(Uri.parse('https://example.com'));

        expect(response.headers['content-type'], 'application/json');
        expect(response.body, '{"wave_height":1.2}');
      },
    );

    test('given a request, send -> records it for later assertions', () async {
      final client = FakeHttpClient();
      client.queueResponse(host: 'example.com', body: 'ok');

      await client.get(Uri.parse('https://example.com/a?x=1'));
      await client.get(Uri.parse('https://example.com/b'));

      expect(client.requests, hasLength(2));
      expect(client.requests[0].url.path, '/a');
      expect(client.requests[1].url.path, '/b');
    });

    test(
      'given no matching queued response, send -> throws a descriptive error',
      () async {
        final client = FakeHttpClient();

        await expectLater(
          () => client.get(Uri.parse('https://unqueued.example.com')),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('unqueued.example.com'),
            ),
          ),
        );
      },
    );

    test(
      'given two queued responses for the same host, send -> the most recently queued one wins',
      () async {
        final client = FakeHttpClient();
        client.queueResponse(host: 'example.com', body: 'first');
        client.queueResponse(host: 'example.com', body: 'second');

        final response = await client.get(Uri.parse('https://example.com'));

        expect(response.body, 'second');
      },
    );

    test(
      'given a consumeOnce response, send twice -> the second call falls through to the next match',
      () async {
        final client = FakeHttpClient();
        client.queueResponse(
          host: 'example.com',
          body: 'retry-me',
          statusCode: 503,
          consumeOnce: true,
        );
        client.queueResponse(
          host: 'example.com',
          body: 'steady-state',
          statusCode: 200,
        );

        final first = await client.get(Uri.parse('https://example.com'));
        final second = await client.get(Uri.parse('https://example.com'));

        expect(first.statusCode, 503);
        expect(second.statusCode, 200);
        expect(second.body, 'steady-state');
      },
    );

    test('given a delay, send -> waits that long before resolving', () async {
      final client = FakeHttpClient();
      client.queueResponse(
        host: 'example.com',
        body: 'slow',
        delay: const Duration(milliseconds: 20),
      );

      final stopwatch = Stopwatch()..start();
      await client.get(Uri.parse('https://example.com'));
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(20));
    });

    test(
      'given a pathContains matcher, send -> only matches requests whose path contains it',
      () async {
        final client = FakeHttpClient();
        client.queueResponse(pathContains: '/v1/marine', body: 'marine');
        client.queueResponse(pathContains: '/v1/forecast', body: 'forecast');

        final marine = await client.get(
          Uri.parse('https://api.example.com/v1/marine'),
        );
        final forecast = await client.get(
          Uri.parse('https://api.example.com/v1/forecast'),
        );

        expect(marine.body, 'marine');
        expect(forecast.body, 'forecast');
      },
    );
  });
}
