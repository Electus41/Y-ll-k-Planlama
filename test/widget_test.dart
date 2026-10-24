import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kocaeli_genc_ihh_takip/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const KocaeliGenclikApp());

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
