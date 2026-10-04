# Testing conventions

BeachIQ's tests follow a JUnit-style structure: one test class/file per production class, shared
fixtures and fakes instead of ad-hoc ones per file, a null-safe mocking library for the rare case a
fake isn't the better fit, and the naming/layout below so any PR (human or automated) tests the same
way.

## Layout

Tests mirror `lib/`: `lib/a/b/foo.dart` -> `test/a/b/foo_test.dart`. Screens, flows and map features
that a user can reach also get coverage in `integration_test/app_test.dart`.

Shared test infrastructure lives in `test/helpers/`:

- `fake_http_client.dart` — `FakeHttpClient`, a scripted `http.Client`. Queue a response per
  host/path (or a custom matcher) with `queueResponse`/`queueJson`, then make calls; every request is
  recorded on `client.requests` for assertions. Never reaches the real network.
- `fixtures.dart` — `loadFixtureString`/`loadFixtureJson` to read `test/fixtures/*.json`.
- `builders.dart` — `aBeach(...)`, `aSeaCondition(...)`, `aWeatherCondition(...)`,
  `aWeatherHourly(...)`, `anAmenity(...)`: each returns a valid instance with sensible defaults: pass
  only the named argument(s) a test cares about.
- `pump_app.dart` — `pumpApp(tester, widget)` pumps a widget in a bare `MaterialApp` and settles;
  `FakeTileProvider` avoids the real OSM tile network; `aLoadedMarineProvider`/
  `aLoadedWeatherProvider` build a provider whose data is already resolved;
  `fakeNearbyBeachesProvider` wires one to a `FakeHttpClient` and a throwaway `SharedPreferences`.

Use `mocktail` (no code generation) only when neither a builder nor `FakeHttpClient` fits, e.g.
verifying a collaborator was called with specific arguments without re-implementing it as a fake.

## Naming and grouping

- One `group('ClassName', ...)` per class under test, with a nested `group('methodName', ...)` per
  method/entry point.
- Test names read `given <state>, <action> -> <expected>`, e.g.
  `given a cache hit, pickLocation -> resolves without calling Overpass`.

## Arrange / Act / Assert

- One behavior per test. Use `setUp`/`tearDown` for state shared across a group's tests, and make
  sure no test depends on another having run first (order independence).
- Every acceptance criterion in an issue gets at least one test that fails without the change and
  passes with it — that test is what proves the criterion, not just that the code compiles.

## No real network or clock

- Inject `FakeHttpClient` (or `package:http/testing.dart`'s `MockClient` for a single-callback case)
  instead of calling the network. A class that currently calls the global `http.get`/`http.post`
  functions instead of taking an injected `http.Client` can still be tested via
  `http.runWithClient(body, () => fakeClient)`.
- Inject a fixed `now` (most providers/services that care about time accept a
  `DateTime Function()? now` constructor parameter) instead of depending on `DateTime.now()`.

## Edge cases are mandatory

For any function/model touching external data, cover: `null`, an empty list, malformed JSON, a
wrap-around or out-of-range value (e.g. a compass bearing), and values at a threshold boundary
(e.g. the exact cutoff between two swim-suitability bands).

## Widget and integration tests

- Widget tests use `pump_app.dart`'s `pumpApp`/fakes instead of hand-rolling a `MaterialApp` and tile
  provider per file.
- A new screen, flow, or map feature extends `integration_test/app_test.dart` in addition to its
  widget tests.

## Checkstyle (format + strict lints)

`tools/checkstyle.sh` is the CI gate that fails the build on formatting drift or a lint violation,
the same way a checkstyle run fails a Java build. It runs `dart format --set-exit-if-changed` and
`dart analyze --fatal-infos --fatal-warnings` (flutter_lints plus the extra strict rules in
`analysis_options.yaml`) and prints one `file:line rule message` line per violation, then a
`Checkstyle summary: SUCCESS ✅`/`FAILURE ❌` line. Run it locally before pushing:

```
bash tools/checkstyle.sh
```

It's covered by `test/tools/checkstyle_test.dart`, which points the script (via its optional
directory argument) at tiny fixtures under `tools/test_fixtures/checkstyle/` to exercise the
formatting-violation, lint-violation and success paths without depending on the rest of the repo.
