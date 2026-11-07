import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_camp/src/art/art_raster_cache.dart';
import 'package:merge_camp/src/art/sticker_art.dart';
import 'package:merge_camp/src/audio/sound_mute_store.dart';
import 'package:merge_camp/src/game/how_to_play.dart';
import 'package:merge_camp/src/game/merge_camp_controller.dart';
import 'package:merge_camp/src/game/merge_camp_screen.dart';
import 'package:merge_camp/src/meta/camp_progress.dart';
import 'package:merge_camp/src/meta/camp_progress_store.dart';
import 'package:merge_camp/src/meta/camp_theme.dart';
import 'package:merge_camp/src/meta/missions.dart';
import 'package:merge_camp/src/meta/stickers.dart';
import 'package:merge_camp/src/platform/game_platform.dart';

class _SeenStore extends HowToPlayStore {
  const _SeenStore();
  @override
  Future<bool> loadSeen() async => true;
  @override
  Future<void> markSeen() async {}
}

class _UnmutedStore extends SoundMuteStore {
  const _UnmutedStore();
  @override
  Future<bool> loadMuted() async => false;
  @override
  Future<void> saveMuted(bool muted) async {}
}

/// Always picks index 0, so the first mission set is fixed.
class _ZeroRandom implements Random {
  @override
  int nextInt(int max) => 0;
  @override
  double nextDouble() => 0;
  @override
  bool nextBool() => false;
}

class _RecordingPlatform extends NoopGamePlatform {
  _RecordingPlatform() : super(allowsResultRegistration: false);
  final List<String> events = <String>[];
  @override
  void gameplayStart() => events.add('start');
  @override
  void gameplayStop() => events.add('stop');
}

int _xpForLevel(int level) {
  var total = 0;
  for (var l = 1; l < level; l++) {
    total += CampProgress.xpToAdvance(l);
  }
  return total;
}

CampProgress _progress({
  int level = 1,
  int extraXp = 0,
  int? seen,
  Map<int, String> slots = const {},
}) {
  var p = CampProgress(
    bestScore: 10,
    discoveredTiers: const {1},
    totalXp: _xpForLevel(level) + extraXp,
    selectedTheme: CampTheme.summer,
    stickersSeen: seen,
  );
  slots.forEach((slot, id) => p = p.withSticker(id, slot));
  return p;
}

Future<(MergeCampController, MemoryCampProgressStore)> _pump(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  CampProgress progress = const CampProgress.initial(),
  GamePlatform platform = const NoopGamePlatform(
    allowsResultRegistration: false,
  ),
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
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = MergeCampController(random: Random(0));
  addTearDown(controller.dispose);
  final store = MemoryCampProgressStore(progress);
  await tester.pumpWidget(
    MaterialApp(
      home: MergeCampScreen(
        controller: controller,
        howToPlayStore: const _SeenStore(),
        soundMuteStore: const _UnmutedStore(),
        progressStore: store,
        missions: MissionBoard(random: _ZeroRandom()),
        platform: platform,
        animateArt: false,
      ),
    ),
  );
  await tester.pump();
  return (controller, store);
}

Finder _cell(int index) => find
    .descendant(
      of: find.byType(GridView),
      matching: find.byType(GestureDetector),
    )
    .at(index);

Finder _slot(int slot) => find.byKey(ValueKey('decor-slot-$slot'));
Finder _tray(String id) => find.byKey(ValueKey('decor-sticker-$id'));

/// Checkerboard of tiers 1 and 2 with the last cell empty: placing a tier-3
/// tile fills the board and ends the run.
void _loadOneMoveFromGameOver(MergeCampController c, {int score = 0}) {
  final board = List<int?>.generate(
    MergeCampController.cellCount,
    (index) => (index ~/ 4 + index % 4).isEven ? 1 : 2,
  );
  board[15] = null;
  c.debugLoadBoard(
    board,
    nextTier: 3,
    trailAxes: 0,
    score: score,
    placements: 10,
    lastAwardedAxeAt: 10,
  );
}

BoardStickerPainter _boardLayer(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(find.byKey(const ValueKey('board-stickers')))
            .painter!
        as BoardStickerPainter;

/// Screen rects of the stickers drawn around the board.
List<Rect> _boardStickerRects(WidgetTester tester) {
  final painter = _boardLayer(tester);
  final origin = tester.getTopLeft(
    find.byKey(const ValueKey('board-stickers')),
  );
  final d = StickerSlotGeometry.diameter(painter.lane);
  return [
    for (final slot in painter.slots.occupied)
      if (painter.showSides || !StickerSlotGeometry.isSide(slot))
        Rect.fromCenter(
          center:
              origin +
              painter.boardRect.topLeft +
              StickerSlotGeometry.center(
                slot,
                painter.boardRect.width,
                painter.lane,
              ),
          width: d,
          height: d,
        ),
  ];
}

void main() {
  testWidgets('decor screen places, swaps and removes stickers', (
    tester,
  ) async {
    final (_, store) = await _pump(
      tester,
      progress: _progress(level: 3, seen: 3),
    );
    await tester.tap(find.byTooltip('Decorate'));
    await tester.pumpAndSettle();
    expect(find.text('Decorate Camp'), findsOneWidget);
    expect(find.text('3 / 25 stickers'), findsOneWidget);
    // Locked stickers show their level and cannot be picked.
    expect(find.text('Lv 25'), findsOneWidget);
    await tester.ensureVisible(_tray('star-badge'));
    await tester.tap(_tray('star-badge'));
    await tester.pump();
    expect(
      find.text('Pick a sticker, then a slot around the board.'),
      findsOneWidget,
    );

    // Pick, then stick.
    await tester.ensureVisible(_tray('acorn'));
    await tester.tap(_tray('acorn'));
    await tester.pump();
    expect(find.text('Tap a slot to stick Acorn.'), findsOneWidget);
    await tester.ensureVisible(_slot(0));
    await tester.tap(_slot(0));
    await tester.pump();
    expect(store.value.stickerSlots.at(0), 'acorn');

    // A tray sticker onto an occupied slot sends the occupant to the tray.
    await tester.ensureVisible(_tray('pennant'));
    await tester.tap(_tray('pennant'));
    await tester.pump();
    await tester.ensureVisible(_slot(0));
    await tester.tap(_slot(0));
    await tester.pump();
    expect(store.value.stickerSlots.at(0), 'pennant');
    expect(store.value.stickerSlots.slotOf('acorn'), isNull);

    // Move onto an empty slot, then swap two stuck stickers.
    await tester.tap(_tray('acorn'));
    await tester.pump();
    await tester.tap(_slot(4));
    await tester.pump();
    await tester.tap(_slot(0));
    await tester.pump();
    expect(find.textContaining('Tap a slot to move Pennant'), findsOneWidget);
    await tester.tap(_slot(4));
    await tester.pump();
    expect(store.value.stickerSlots.at(4), 'pennant');
    expect(store.value.stickerSlots.at(0), 'acorn');
    expect(store.value.stickerSlots.length, 2);

    // Tapping a stuck sticker twice takes it off.
    await tester.tap(_slot(4));
    await tester.pump();
    await tester.tap(_slot(4));
    await tester.pump();
    expect(store.value.stickerSlots.at(4), isNull);
    expect(store.value.stickerSlots.toJson(), {'0': 'acorn'});
    expect(store.value.activeRun, isNull);

    await tester.tap(find.byTooltip('Close decorate'));
    await tester.pumpAndSettle();
    expect(find.text('Decorate Camp'), findsNothing);
    expect(_boardLayer(tester).slots.at(0), 'acorn');
  });

  testWidgets('board input is blocked while the decor screen is open', (
    tester,
  ) async {
    final platform = _RecordingPlatform();
    final (controller, _) = await _pump(
      tester,
      progress: _progress(level: 2, seen: 2),
      platform: platform,
    );
    expect(platform.events, ['start']);
    await tester.tap(find.byTooltip('Decorate'));
    await tester.pumpAndSettle();
    expect(platform.events, ['start', 'stop']);
    for (final key in const [
      LogicalKeyboardKey.keyR,
      LogicalKeyboardKey.keyX,
      LogicalKeyboardKey.keyD,
    ]) {
      await tester.sendKeyEvent(key);
      await tester.pump();
    }
    await tester.tap(_cell(5), warnIfMissed: false);
    await tester.pump();
    expect(controller.placements, 0);
    expect(controller.board.every((t) => t == null), isTrue);
    expect(find.byKey(const ValueKey('keyboard-cursor')), findsNothing);

    // Keyboard: the first sticker has focus, Enter picks it, an arrow moves
    // to a slot and Enter sticks it there.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('Tap a slot to stick Pennant.'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(_boardLayer(tester).slots.slotOf('pennant'), isNotNull);
    expect(controller.placements, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Decorate Camp'), findsNothing);
    expect(platform.events, ['start', 'stop', 'start']);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'MergeCampBoard');
    await tester.tap(_cell(5));
    await tester.pump();
    expect(controller.placements, 1);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('existing players get one quiet notice, nothing auto-placed', (
    tester,
  ) async {
    final (_, store) = await _pump(tester, progress: _progress(level: 7));
    expect(find.text('7 stickers ready to place'), findsOneWidget);
    expect(find.textContaining('New sticker'), findsNothing);
    expect(store.value.stickersSeen, 7);
    expect(store.value.stickerSlots.isEmpty, isTrue);
    expect(store.value.stickerTray, hasLength(7));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('7 stickers ready to place'), findsNothing);
  });

  testWidgets('the notice is not shown again once seen', (tester) async {
    await _pump(tester, progress: _progress(level: 7, seen: 7));
    expect(find.textContaining('ready to place'), findsNothing);
  });

  testWidgets('brand-new players start with the Pennant on the board', (
    tester,
  ) async {
    final (_, store) = await _pump(tester);
    expect(find.textContaining('ready to place'), findsNothing);
    expect(find.textContaining('New sticker'), findsNothing);
    expect(store.value.stickersSeen, 1);
    expect(store.value.stickerSlots.toJson(), {'0': 'pennant'});
    expect(_boardLayer(tester).slots.at(0), 'pennant');
    // The first move keeps it; a later load does not place it again.
    await tester.tap(_cell(0));
    await tester.pump();
    expect(store.value.stickerSlots.toJson(), {'0': 'pennant'});
    expect(store.value.activeRun, isNotNull);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('a level-up sticks the new sticker and the summary shows it', (
    tester,
  ) async {
    final (controller, store) = await _pump(
      tester,
      progress: _progress(level: 1, extraXp: 200, seen: 1),
    );
    _loadOneMoveFromGameOver(controller, score: 2000);
    await tester.tap(_cell(15));
    await tester.pumpAndSettle();
    expect(find.text('Camp jammed!'), findsOneWidget);
    expect(store.value.level, 2);
    expect(find.text('Level up! Lv 2'), findsOneWidget);
    expect(find.text('New sticker: Pine Tree'), findsOneWidget);
    expect(store.value.stickerSlots.at(0), 'pine-tree');
    expect(store.value.stickersSeen, 2);
    expect(_boardLayer(tester).slots.at(0), 'pine-tree');

    // Decorate from the summary; closing returns focus to Play again.
    await tester.ensureVisible(find.text('Decorate'));
    await tester.tap(find.text('Decorate'));
    await tester.pumpAndSettle();
    expect(find.text('Decorate Camp'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Decorate Camp'), findsNothing);
    expect(find.text('Camp jammed!'), findsOneWidget);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'PlayAgain');
  });

  testWidgets('the board sticker layer is cached per placement', (
    tester,
  ) async {
    final wasEnabled = ArtRasterCache.enabled;
    ArtRasterCache.enabled = true;
    addTearDown(() => ArtRasterCache.enabled = wasEnabled);
    final (controller, _) = await _pump(
      tester,
      size: const Size(1280, 720),
      progress: _progress(level: 9, seen: 9, slots: {7: 'compass'}),
    );
    await tester.pump();
    final first = BoardStickerPainter.debugRasterCount;
    // Other changes on screen reuse the cached layer.
    await tester.tap(_cell(0));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 3));
    expect(controller.placements, 1);
    expect(BoardStickerPainter.debugRasterCount, first);

    await tester.tap(find.byTooltip('Decorate'));
    await tester.pumpAndSettle();
    await tester.tap(_tray('mug'));
    await tester.pump();
    await tester.tap(_slot(2));
    await tester.pump();
    await tester.tap(find.byTooltip('Close decorate'));
    await tester.pumpAndSettle();
    expect(BoardStickerPainter.debugRasterCount, first + 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a mid-run restart toasts the new stickers', (tester) async {
    Future<void> restartAfter(int levelsUp, String toast) async {
      final (controller, store) = await _pump(
        tester,
        progress: _progress(level: 1, seen: 1),
      );
      final need = _xpForLevel(1 + levelsUp) - store.value.totalXp;
      // Five placements and one merge earn participation XP on top.
      controller.debugLoadBoard(
        List<int?>.filled(16, null),
        nextTier: 1,
        previewTiers: const [1, 1, 1, 1, 1],
        score: (need - CampProgress.participationXp) * 10,
      );
      for (final cell in const [0, 1, 2, 8, 10]) {
        await tester.tap(_cell(cell));
        await tester.pump();
      }
      expect(controller.mergeCount, greaterThan(0));
      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.pump();
      expect(store.value.level, 1 + levelsUp);
      expect(find.text(toast), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    }

    await restartAfter(1, 'New sticker: Pine Tree');
    await tester.pumpWidget(const SizedBox());
    await restartAfter(2, 'New stickers: Pine Tree, Acorn');
  });

  for (final size in const [
    Size(1280, 720),
    Size(1280, 672),
    Size(1366, 768),
    Size(390, 844),
    Size(390, 796),
    Size(844, 390),
    Size(360, 640),
    Size(640, 480),
    Size(320, 640),
  ]) {
    testWidgets('stickers and decor screen fit $size', (tester) async {
      final full = {
        for (var slot = 0; slot < StickerSlots.count; slot++)
          slot: Sticker.catalog[24 - slot].id,
      };
      final (controller, _) = await _pump(
        tester,
        size: size,
        progress: _progress(level: 25, seen: 25, slots: full),
      );
      expect(tester.takeException(), isNull);
      final sides = _boardLayer(tester).showSides;
      if (size == const Size(1280, 720) || size == const Size(1366, 768)) {
        expect(sides, isTrue);
      }
      if (size == const Size(390, 844)) expect(sides, isFalse);
      final grid = tester.getRect(find.byType(GridView));
      final board = tester.getRect(find.byKey(const ValueKey('board-content')));
      final rects = _boardStickerRects(tester);
      expect(rects, hasLength(sides ? 10 : 6));
      for (final rect in rects) {
        expect(rect.overlaps(grid), isFalse);
        expect(rect.overlaps(board), isFalse);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(size.width));
        expect(rect.bottom, lessThanOrEqualTo(size.height));
      }

      await tester.tap(find.byTooltip('Decorate'));
      await tester.pumpAndSettle();
      expect(find.text('Decorate Camp'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      _loadOneMoveFromGameOver(controller, score: 100);
      await tester.tap(_cell(15));
      await tester.pumpAndSettle();
      expect(find.text('Camp jammed!'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Decorate'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Decorate'));
      await tester.pumpAndSettle();
      expect(find.text('Decorate Camp'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('every sticker paints cached, as vectors and as silhouette', (
    tester,
  ) async {
    final wasEnabled = ArtRasterCache.enabled;
    addTearDown(() => ArtRasterCache.enabled = wasEnabled);
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    for (final cached in [false, true]) {
      ArtRasterCache.enabled = cached;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Wrap(
            children: [
              for (final sticker in Sticker.catalog) ...[
                SizedBox.square(
                  dimension: 48,
                  child: StickerArt(sticker: sticker, sparkle: true),
                ),
                SizedBox.square(
                  dimension: 30,
                  child: StickerArt(sticker: sticker, silhouette: true),
                ),
              ],
            ],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  });
}
