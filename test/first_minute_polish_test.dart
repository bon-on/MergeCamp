import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_camp/src/art/art_raster_cache.dart';
import 'package:merge_camp/src/art/camp_tile_art.dart';
import 'package:merge_camp/src/art/tile_warmup.dart';
import 'package:merge_camp/src/audio/sound_mute_store.dart';
import 'package:merge_camp/src/game/how_to_play.dart';
import 'package:merge_camp/src/game/merge_camp_controller.dart';
import 'package:merge_camp/src/game/merge_camp_screen.dart';
import 'package:merge_camp/src/meta/camp_progress_store.dart';
import 'package:merge_camp/src/meta/camp_theme.dart';
import 'package:merge_camp/src/meta/missions.dart';

// Acceptance tests for harness/specs/feature-first-minute-polish.md.

class _NewPlayer extends HowToPlayStore {
  bool seen = false;
  @override
  Future<bool> loadSeen() async => seen;
  @override
  Future<void> markSeen() async => seen = true;
}

class _Unmuted extends SoundMuteStore {
  const _Unmuted();
  @override
  Future<bool> loadMuted() async => false;
  @override
  Future<void> saveMuted(bool muted) async {}
}

Finder _cell(int index) => find
    .descendant(
      of: find.byType(GridView),
      matching: find.byType(GestureDetector),
    )
    .at(index);

final _coach = find.byKey(const ValueKey('coach-hint'));

Future<MergeCampController> _startPractice(
  WidgetTester tester, {
  double dpr = 1,
}) async {
  for (final channel in const [
    MethodChannel('merge_camp/audio'),
    SystemChannels.platform,
  ]) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
  }
  tester.view.physicalSize = Size(390 * dpr, 844 * dpr);
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
  final controller = MergeCampController(random: Random(0));
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: MergeCampScreen(
        controller: controller,
        missions: MissionBoard(random: Random(0)),
        howToPlayStore: _NewPlayer(),
        soundMuteStore: const _Unmuted(),
        progressStore: MemoryCampProgressStore(),
        animateArt: false,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  // A first run starts the guided merge without a card.
  await tester.pump();
  return controller;
}

void main() {
  testWidgets('after the practice merge a next-step hint shows, then fades', (
    tester,
  ) async {
    final c = await _startPractice(tester);
    expect(_coach, findsNothing, reason: 'practice caption owns the strip');
    await tester.tap(_cell(2));
    await tester.pump();
    expect(c.placements, 1);
    expect(_coach, findsOneWidget);
    expect(find.text('Skip practice'), findsNothing);

    // Still up after the second and third placements, gone after the fourth.
    for (final cell in [9, 10]) {
      await tester.tap(_cell(cell));
      await tester.pump();
    }
    expect(c.placements, 3);
    expect(_coach, findsOneWidget);
    await tester.tap(_cell(15));
    await tester.pump();
    expect(c.placements, 4);
    expect(_coach, findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('skipping the practice never shows the hint', (tester) async {
    final c = await _startPractice(tester);
    await tester.tap(find.text('Skip practice'));
    await tester.pump();
    await tester.tap(_cell(9));
    await tester.pump();
    expect(c.placements, 1);
    expect(_coach, findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('restarting after the practice merge clears the hint', (
    tester,
  ) async {
    final c = await _startPractice(tester);
    await tester.tap(_cell(2));
    await tester.pump();
    expect(_coach, findsOneWidget);
    c.restart();
    await tester.pump();
    expect(_coach, findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });

  for (final dpr in const [1.0, 2.0, 3.0]) {
    testWidgets('warm-up tiles match real board tiles at DPR $dpr', (
      tester,
    ) async {
      final saved = ArtRasterCache.enabled;
      ArtRasterCache.enabled = true;
      addTearDown(() => ArtRasterCache.enabled = saved);
      await _startPractice(tester, dpr: dpr);
      await tester.pump(const Duration(milliseconds: 130));
      int px(Size size) => (size.width * dpr).ceil();
      // Practice board: cell 0 holds a real tier-1 tile.
      final real = tester.getSize(
        find
            .descendant(
              of: find.byType(GridView),
              matching: find.byType(CampTileArt),
            )
            .first,
      );
      final warm = tester.getSize(find.byKey(const ValueKey('warm-1-false')));
      expect(px(warm), px(real), reason: 'board tile key');
      final warmPreview = tester.getSize(
        find.descendant(
          of: find.byKey(const ValueKey('warm-preview-1')),
          matching: find.byType(CampTileArt),
        ),
      );
      final realPreview = tester.getSize(
        find
            .descendant(
              of: find.byKey(const ValueKey('placement-preview')),
              matching: find.byType(CampTileArt),
            )
            .first,
      );
      expect(px(warmPreview), px(realPreview), reason: 'preview key');
      await tester.pump(const Duration(seconds: 1));
    });
  }

  group('TileWarmup', () {
    Widget host() => const Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [TileWarmup(cell: 80, theme: CampTheme.summer, tiers: 3)],
      ),
    );

    testWidgets('mounts tiers one step at a time, then removes itself', (
      tester,
    ) async {
      final saved = ArtRasterCache.enabled;
      ArtRasterCache.enabled = true;
      addTearDown(() => ArtRasterCache.enabled = saved);
      await tester.pumpWidget(host());
      expect(find.byType(CampTileArt), findsNothing);
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.byType(CampTileArt), findsNWidgets(3), reason: 'tier 1');
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.byType(CampTileArt), findsNWidgets(6), reason: 'tiers 1-2');
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.byType(CampTileArt), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('does nothing where the raster cache is off', (tester) async {
      final saved = ArtRasterCache.enabled;
      ArtRasterCache.enabled = false;
      addTearDown(() => ArtRasterCache.enabled = saved);
      await tester.pumpWidget(host());
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(CampTileArt), findsNothing);
    });
  });
}
