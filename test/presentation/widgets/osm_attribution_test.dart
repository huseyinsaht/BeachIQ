import 'package:beachiq/presentation/widgets/osm_attribution.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  testWidgets('renders the OpenStreetMap attribution text', (tester) async {
    await tester.pumpWidget(wrap(const OsmAttribution()));

    expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
  });

  testWidgets('tapping it attempts to launch the copyright URL', (
    tester,
  ) async {
    Uri? launchedUri;

    await tester.pumpWidget(
      wrap(
        OsmAttribution(
          onLaunch: (url) async {
            launchedUri = url;
            return true;
          },
        ),
      ),
    );

    await tester.tap(find.text('© OpenStreetMap contributors'));
    await tester.pump();

    expect(launchedUri, osmCopyrightUri);
    expect(launchedUri.toString(), 'https://www.openstreetmap.org/copyright');
  });
}
