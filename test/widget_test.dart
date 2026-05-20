import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_camp/src/app/merge_camp_app.dart';

void main() {
  testWidgets('MergeCamp renders scaffold and title', (tester) async {
    await tester.pumpWidget(const MergeCampApp());
    await tester.pump();

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('MergeCamp'), findsOneWidget);
  });
}
