import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_camp/src/game/how_to_play.dart';
import 'package:merge_camp/src/app/merge_camp_app.dart';
import 'package:merge_camp/src/meta/camp_progress_store.dart';

class _SeenStore extends HowToPlayStore {
  const _SeenStore();
  @override
  Future<bool> loadSeen() async => true;
  @override
  Future<void> markSeen() async {}
}

void main() {
  testWidgets('MergeCamp renders scaffold and title', (tester) async {
    await tester.pumpWidget(
      MergeCampApp(
        howToPlayStore: const _SeenStore(),
        progressStore: MemoryCampProgressStore(),
      ),
    );
    await tester.pump();

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('MergeCamp'), findsOneWidget);
  });
}
