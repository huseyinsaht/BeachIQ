import 'dart:convert';

import 'package:http/http.dart' as http;

/// Matches an outgoing request so [FakeHttpClient] knows which queued
/// response to answer it with.
typedef RequestMatcher = bool Function(http.BaseRequest request);

class _QueuedResponse {
  _QueuedResponse({
    required this.matcher,
    required this.body,
    required this.statusCode,
    required this.headers,
    required this.consumeOnce,
    required this.delay,
  });

  final RequestMatcher matcher;
  final String body;
  final int statusCode;
  final Map<String, String> headers;
  final bool consumeOnce;
  final Duration delay;
}

/// A scripted [http.Client] that never touches the real network: tests
/// queue a response per host/path (or a custom matcher), and every request
/// made against this client is recorded for later assertions.
///
/// By default a queued response is "sticky" (it keeps answering every
/// matching request, last-registered-wins when matchers overlap), which
/// covers the common case of one fixture per endpoint. Pass
/// `consumeOnce: true` to script a sequence (e.g. a failure then a
/// success on retry) — each queued entry is used once and removed.
class FakeHttpClient extends http.BaseClient {
  final List<_QueuedResponse> _responses = [];

  /// Every request this client has received, in order, for assertions
  /// like "sent the expected latitude/longitude" or "called once".
  final List<http.BaseRequest> requests = [];

  /// Queues a raw-body response for requests matching [host]/[pathContains]
  /// (both optional, combined with AND) or a custom [matcher]. At least one
  /// of [host], [pathContains] or [matcher] must be given.
  void queueResponse({
    String? host,
    String? pathContains,
    RequestMatcher? matcher,
    String body = '',
    int statusCode = 200,
    Map<String, String> headers = const {},
    bool consumeOnce = false,
    Duration delay = Duration.zero,
  }) {
    assert(
      host != null || pathContains != null || matcher != null,
      'FakeHttpClient.queueResponse needs a host, pathContains or matcher',
    );
    final effectiveMatcher =
        matcher ??
        (request) {
          if (host != null && request.url.host != host) return false;
          if (pathContains != null &&
              !request.url.path.contains(pathContains)) {
            return false;
          }
          return true;
        };
    _responses.add(
      _QueuedResponse(
        matcher: effectiveMatcher,
        body: body,
        statusCode: statusCode,
        headers: headers,
        consumeOnce: consumeOnce,
        delay: delay,
      ),
    );
  }

  /// Convenience for [queueResponse] with a JSON-encoded body and the
  /// matching content-type header.
  void queueJson({
    String? host,
    String? pathContains,
    RequestMatcher? matcher,
    required Object? json,
    int statusCode = 200,
    bool consumeOnce = false,
    Duration delay = Duration.zero,
  }) {
    queueResponse(
      host: host,
      pathContains: pathContains,
      matcher: matcher,
      body: jsonEncode(json),
      statusCode: statusCode,
      headers: const {'content-type': 'application/json'},
      consumeOnce: consumeOnce,
      delay: delay,
    );
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);

    // consumeOnce entries are tried first, in registration order, so a
    // scripted sequence (e.g. a 429 then a success on retry) plays out in
    // the order it was queued.
    for (var i = 0; i < _responses.length; i++) {
      final queued = _responses[i];
      if (!queued.consumeOnce || !queued.matcher(request)) continue;
      _responses.removeAt(i);
      return _respond(queued);
    }

    // Sticky entries: most-recently-queued wins, so a test can override a
    // default queued earlier in setUp.
    for (var i = _responses.length - 1; i >= 0; i--) {
      final queued = _responses[i];
      if (queued.consumeOnce || !queued.matcher(request)) continue;
      return _respond(queued);
    }

    throw StateError(
      'FakeHttpClient: no queued response for ${request.method} '
      '${request.url}. Queued ${_responses.length} response(s), none '
      'matched. Call queueResponse()/queueJson() before making this '
      'request.',
    );
  }

  Future<http.StreamedResponse> _respond(_QueuedResponse queued) async {
    if (queued.delay > Duration.zero) await Future.delayed(queued.delay);
    return http.StreamedResponse(
      Stream.value(utf8.encode(queued.body)),
      queued.statusCode,
      headers: queued.headers,
    );
  }
}
