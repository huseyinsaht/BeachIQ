import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beachiq/main.dart';

void main() {
  testWidgets('MarineApp renders the home screen without crashing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MarineApp());

    expect(find.byType(Scaffold), findsOneWidget);
  });
}
