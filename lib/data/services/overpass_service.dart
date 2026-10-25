import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Executes an Overpass QL query (as produced by
/// `overpass_query_builder.dart`) against the public Overpass API.
///
/// Resilience features:
///  * several public mirrors are tried with **hedged** requests: the first
///    endpoint starts immediately, the next one starts as soon as the
///    previous one fails or has not answered after [hedgeDelay], and the
///    first successful answer wins (the public servers are often overloaded
///    or unreachable from some networks, so waiting for one at a time could
///    take minutes)
///  * the whole call gives up after [overallTimeout]
///  * HTTP 429 (rate limited) and 504 (gateway timeout) responses, and
///    request timeouts, are retried with a bounded exponential backoff
///    before giving up on an endpoint
///  * concurrent calls for the exact same query string are de-duplicated:
///    a second caller awaits the in-flight request instead of firing a new
///    one
///
/// This service only decodes the Overpass JSON response into a plain
/// `Map<String, dynamic>`. Mapping that structure into domain `Beach`
/// models is out of scope here and is handled elsewhere.
class OverpassService {
  /// The public Overpass instances tried, in order of preference.
  static const List<String> defaultEndpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://overpass.private.coffee/api/interpreter',
    'https://overpass.openstreetmap.fr/api/interpreter',
  ];

  OverpassService(
    this._client, {
    this.endpoints = defaultEndpoints,
    this.timeout = const Duration(seconds: 28),
    this.maxAttemptsPerEndpoint = 2,
    this.initialBackoff = const Duration(milliseconds: 500),
    this.hedgeDelay = const Duration(seconds: 4),
    this.overallTimeout = const Duration(seconds: 40),
  }) : assert(
         endpoints.isNotEmpty,
         'At least one Overpass endpoint is required',
       );

  final http.Client _client;

  /// Overpass endpoints, in order of preference. The first starts
  /// immediately; each next one starts when the previous failed or after
  /// [hedgeDelay] without an answer.
  final List<String> endpoints;

  /// How long to wait for an endpoint before also starting the next one.
  final Duration hedgeDelay;

  /// The whole [query] call fails after this long without any answer.
  final Duration overallTimeout;

  /// Per-request timeout, matching the query's own `[timeout:25]` setting
  /// with a small margin for network overhead.
  final Duration timeout;

  /// Maximum number of attempts against a single endpoint before moving on
  /// to the next one. Only HTTP 429/504 responses trigger a retry.
  final int maxAttemptsPerEndpoint;

  /// Delay before the first retry; doubles after each subsequent retry.
  final Duration initialBackoff;

  static const String _userAgent =
      'BeachIQ/1.0 (+https://github.com/huseyinsaht/BeachIQ)';

  /// In-flight requests keyed by the raw Overpass query string, so
  /// concurrent identical requests share a single HTTP call.
  final Map<String, Future<Map<String, dynamic>>> _inFlight = {};

  /// Runs [overpassQuery] and returns the decoded Overpass JSON response.
  ///
  /// Throws an [Exception] with a descriptive message if every endpoint
  /// fails, or the response body isn't valid Overpass JSON.
  Future<Map<String, dynamic>> query(String overpassQuery) {
    final inFlight = _inFlight[overpassQuery];
    if (inFlight != null) {
      return inFlight;
    }

    final future = _executeWithFallback(overpassQuery);
    _inFlight[overpassQuery] = future;
    // Stop de-duplicating once this request settles (success or failure) so
    // a later, separate call is retried fresh rather than replaying a stale
    // result. The error is swallowed here purely as bookkeeping cleanup;
    // the [future] returned above still delivers it to its own caller(s).
    _forgetWhenDone(overpassQuery, future);

    return future;
  }

  void _forgetWhenDone(
    String overpassQuery,
    Future<Map<String, dynamic>> future,
  ) {
    () async {
      try {
        await future;
      } catch (_) {
        // Already surfaced to callers via the returned future.
      } finally {
        // Not an un-awaited async call: this just drops the stored
        // reference from the de-dup map, whose value type happens to be
        // Future<Map<String, dynamic>>. There is nothing here to await.
        // ignore: unawaited_futures
        _inFlight.remove(overpassQuery);
      }
    }();
  }

  Future<Map<String, dynamic>> _executeWithFallback(String overpassQuery) {
    final completer = Completer<Map<String, dynamic>>();
    final failures = <String>[];
    var started = 0;
    Timer? hedgeTimer;
    Timer? deadline;

    void finish() {
      hedgeTimer?.cancel();
      deadline?.cancel();
    }

    void startNext() {
      if (completer.isCompleted || started >= endpoints.length) return;
      final endpoint = endpoints[started++];
      hedgeTimer?.cancel();
      if (started < endpoints.length) {
        hedgeTimer = Timer(hedgeDelay, startNext);
      }
      _executeWithRetry(endpoint, overpassQuery).then(
        (result) {
          if (completer.isCompleted) return;
          completer.complete(result);
          finish();
        },
        onError: (Object e) {
          failures.add('$endpoint failed: $e');
          if (completer.isCompleted) return;
          if (failures.length == endpoints.length) {
            completer.completeError(
              Exception(
                'Overpass request failed on all ${endpoints.length} '
                'endpoint(s): ${failures.join(' | ')}',
              ),
            );
            finish();
          } else {
            startNext();
          }
        },
      );
    }

    deadline = Timer(overallTimeout, () {
      if (completer.isCompleted) return;
      completer.completeError(
        Exception(
          'Overpass request failed: no endpoint answered within '
          '${overallTimeout.inSeconds}s'
          '${failures.isEmpty ? '' : ' (${failures.join(' | ')})'}',
        ),
      );
      finish();
    });
    startNext();
    return completer.future;
  }

  Future<Map<String, dynamic>> _executeWithRetry(
    String endpoint,
    String overpassQuery,
  ) async {
    var attempt = 0;
    var backoff = initialBackoff;

    while (true) {
      attempt++;
      http.Response response;
      try {
        response = await _client
            .post(
              Uri.parse(endpoint),
              headers: const {'User-Agent': _userAgent},
              body: {'data': overpassQuery},
            )
            .timeout(timeout);
      } on TimeoutException {
        if (attempt < maxAttemptsPerEndpoint) {
          await Future.delayed(backoff);
          backoff *= 2;
          continue;
        }
        throw Exception(
          'Timed out waiting for a response after $attempt attempt(s)',
        );
      }

      if (response.statusCode == 200) {
        return _decodeBody(response.body);
      }

      final isRetryable =
          response.statusCode == 429 || response.statusCode == 504;
      if (isRetryable && attempt < maxAttemptsPerEndpoint) {
        await Future.delayed(backoff);
        backoff *= 2;
        continue;
      }

      throw Exception('HTTP ${response.statusCode} after $attempt attempt(s)');
    }
  }

  Map<String, dynamic> _decodeBody(String body) {
    Object? decoded;
    try {
      decoded = json.decode(body);
    } on FormatException catch (e) {
      throw Exception('Malformed Overpass JSON response: $e');
    }

    if (decoded is! Map<String, dynamic>) {
      throw Exception(
        'Unexpected Overpass response shape: expected a JSON object',
      );
    }

    return decoded;
  }
}
