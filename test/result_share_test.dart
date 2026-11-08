import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_camp/src/audio/sound_mute_store.dart';
import 'package:merge_camp/src/game/how_to_play.dart';
import 'package:merge_camp/src/game/merge_camp_controller.dart';
import 'package:merge_camp/src/game/merge_camp_screen.dart';
import 'package:merge_camp/src/game/share/result_card.dart';
import 'package:merge_camp/src/game/share/result_share.dart';
import 'package:merge_camp/src/game/ui/run_summary_overlay.dart';
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

class _ZeroRandom implements Random {
  @override
  int nextInt(int max) => 0;
  @override
  double nextDouble() => 0;
  @override
  bool nextBool() => false;
}

class _RecordingPlatform extends NoopGamePlatform {
  _RecordingPlatform({super.shareLink})
    : super(allowsResultRegistration: false);
  final List<String> events = <String>[];
  @override
  void gameplayStart() => events.add('start');
  @override
  void gameplayStop() => events.add('stop');
  @override
  Future<void> showRunBreakAd() async => events.add('ad');
}

class _FakeShare extends ResultShare {
  _FakeShare({
    this.copyOk = true,
    this.saveOk = true,
    this.shareStatus = ShareStatus.done,
    this.canSaveImage = true,
    this.canShare = true,
    this.throws = false,
  });

  final bool copyOk;
  final bool saveOk;
  final ShareStatus shareStatus;
  @override
  final bool canSaveImage;
  @override
  final bool canShare;
  final bool throws;

  final List<String> copied = <String>[];
  final List<Uint8List> saved = <Uint8List>[];
  final List<(String, Uint8List?)> shared = <(String, Uint8List?)>[];

  @override
  Future<bool> copyText(String text) async {
    if (throws) throw StateError('clipboard');
    copied.add(text);
    return copyOk;
  }

  @override
  Future<bool> saveImage(Uint8List png, String fileName) async {
    if (throws) throw StateError('download');
    saved.add(png);
    return saveOk;
  }

  @override
  Future<ShareStatus> share({
    required String text,
    Uint8List? png,
    required String fileName,
  }) async {
    if (throws) throw StateError('share');
    shared.add((text, png));
    return shareStatus;
  }
}

final Uint8List _fakePng = Uint8List.fromList([137, 80, 78, 71, 1, 2, 3]);

Future<MergeCampController> _pump(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  GamePlatform? platform,
  ResultShare? share,
  CampProgress progress = const CampProgress.initial(),
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
  await tester.pumpWidget(
    MaterialApp(
      home: MergeCampScreen(
        controller: controller,
        howToPlayStore: const _SeenStore(),
        soundMuteStore: const _UnmutedStore(),
        progressStore: MemoryCampProgressStore(progress),
        missions: MissionBoard(random: _ZeroRandom()),
        platform: platform ?? _RecordingPlatform(shareLink: pagesShareLink),
        resultShare: share ?? _FakeShare(),
        animateArt: false,
      ),
    ),
  );
  await tester.pump();
  return controller;
}

/// Fills the board but one plot; placing the tier-3 piece ends the run.
Future<void> _finishRun(WidgetTester tester, MergeCampController c) async {
  final board = List<int?>.generate(
    MergeCampController.cellCount,
    (index) => (index ~/ 4 + index % 4).isEven ? 1 : 2,
  );
  board[15] = null;
  c.debugLoadBoard(
    board,
    nextTier: 3,
    trailAxes: 0,
    score: 120,
    placements: 10,
    lastAwardedAxeAt: 10,
  );
  await tester.tap(
    find
        .descendant(
          of: find.byType(GridView),
          matching: find.byType(GestureDetector),
        )
        .at(15),
  );
  await tester.pumpAndSettle();
  expect(find.text('Camp jammed!'), findsOneWidget);
}

Future<void> _tapButton(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
  await tester.pump();
}

Future<void> _pumpOverlay(
  WidgetTester tester, {
  required ResultShare share,
  required ResultCardRenderer renderCard,
  CampProgress progress = const CampProgress.initial(),
  CampTheme theme = CampTheme.snow,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final focus = FocusNode();
  addTearDown(focus.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: RunSummaryOverlay(
        report: const RunReport(
          score: 77,
          highestTier: 4,
          bestChain: 2,
          missionsCompleted: 1,
        ),
        theme: theme,
        progress: progress,
        board: const [1, 2, null, 3],
        shareLink: 'https://example.test/',
        share: share,
        renderCard: renderCard,
        playAgainFocus: focus,
        animateArt: false,
        onPlayAgain: () {},
        onAlbum: () {},
        onDecorate: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('summary shows the next goals with numbers', (tester) async {
    final c = await _pump(tester);
    await _finishRun(tester, c);
    expect(find.byKey(const ValueKey('summary-next-goals')), findsOneWidget);
    expect(find.text('NEXT GOAL'), findsOneWidget);
    final highlight = find.byKey(const ValueKey('next-goal-highlight'));
    expect(highlight, findsOneWidget);
    expect(
      find.descendant(
        of: highlight,
        matching: find.textContaining(RegExp(r'^\d+ XP to Lv 2$')),
      ),
      findsOneWidget,
    );
    expect(find.text('Unlocks the Pine Tree sticker'), findsOneWidget);
    expect(
      find.textContaining(RegExp(r'^Build a .+ - New album camp')),
      findsOneWidget,
    );
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
    testWidgets('summary with share actions fits $size', (tester) async {
      final c = await _pump(tester, size: size);
      await _finishRun(tester, c);
      expect(tester.takeException(), isNull);
      final play = tester.getRect(
        find.byKey(const ValueKey('summary-play-again')),
      );
      // Always on screen without scrolling, and the biggest button.
      expect(play.top, greaterThanOrEqualTo(0));
      expect(play.bottom, lessThanOrEqualTo(size.height));
      // The highlighted next goal is pinned in view too.
      final goal = tester.getRect(
        find.byKey(const ValueKey('next-goal-highlight')),
      );
      expect(goal.top, greaterThanOrEqualTo(0));
      expect(goal.bottom, lessThanOrEqualTo(size.height));
      expect(goal.right, lessThanOrEqualTo(size.width));
      for (final label in const [
        'Album',
        'Decorate',
        'Copy result',
        'Save card',
        'Share',
      ]) {
        final button = tester.getRect(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(OutlinedButton),
          ),
        );
        expect(button.bottom, lessThanOrEqualTo(size.height));
        expect(button.right, lessThanOrEqualTo(size.width));
        expect(play.height, greaterThan(button.height));
        expect(play.width, greaterThan(button.width));
      }
    });
  }

  testWidgets('GamePix builds show no share actions', (tester) async {
    final share = _FakeShare();
    final c = await _pump(
      tester,
      platform: const NoopGamePlatform.gamePix(),
      share: share,
    );
    expect(const NoopGamePlatform.gamePix().shareLink, isNull);
    await _finishRun(tester, c);
    expect(find.byKey(const ValueKey('summary-share-row')), findsNothing);
    expect(find.text('Copy result'), findsNothing);
    expect(find.text('Save card'), findsNothing);
    expect(find.text('Share'), findsNothing);
    expect(find.text('Play again'), findsOneWidget);
  });

  testWidgets('unavailable save/share buttons are hidden', (tester) async {
    final c = await _pump(
      tester,
      share: _FakeShare(canSaveImage: false, canShare: false),
    );
    await _finishRun(tester, c);
    expect(find.text('Copy result'), findsOneWidget);
    expect(find.text('Save card'), findsNothing);
    expect(find.text('Share'), findsNothing);
  });

  testWidgets('Copy result copies score, camp, level and link', (tester) async {
    final share = _FakeShare();
    final platform = _RecordingPlatform(shareLink: pagesShareLink);
    final c = await _pump(tester, share: share, platform: platform);
    await _finishRun(tester, c);
    final events = List<String>.of(platform.events);
    await _tapButton(tester, 'Copy result');
    expect(share.copied, [
      'I scored ${c.score} in MergeCamp! Top camp: Supply Shed, camp Lv 1. '
          'https://bon-on.github.io/MergeCamp/',
    ]);
    expect(find.text('Copied!'), findsOneWidget);
    // Sharing never touches gameplay events or ads.
    expect(platform.events, events);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Copied!'), findsNothing);
  });

  testWidgets('Save card and Share render the card once', (tester) async {
    final share = _FakeShare();
    final rendered = <ResultCardData>[];
    await _pumpOverlay(
      tester,
      share: share,
      progress: const CampProgress.initial().withSticker('pennant', 2),
      renderCard: (data) async {
        rendered.add(data);
        return _fakePng;
      },
    );
    await _tapButton(tester, 'Save card');
    expect(find.text('Card saved'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await _tapButton(tester, 'Share');
    await tester.pump(const Duration(seconds: 3));
    expect(rendered, hasLength(1));
    expect(rendered.single.score, 77);
    expect(rendered.single.highestTier, 4);
    expect(rendered.single.board, const [1, 2, null, 3]);
    expect(rendered.single.stickerSlots.at(2), 'pennant');
    expect(rendered.single.theme, CampTheme.snow);
    expect(share.saved.single, _fakePng);
    expect(share.shared.single.$1, endsWith('https://example.test/'));
    expect(share.shared.single.$2, _fakePng);
    expect(find.text('Could not share'), findsNothing);
  });

  testWidgets('the card is rendered again after decorating', (tester) async {
    final share = _FakeShare();
    final rendered = <ResultCardData>[];
    Future<Uint8List?> render(ResultCardData data) async {
      rendered.add(data);
      return _fakePng;
    }

    await _pumpOverlay(tester, share: share, renderCard: render);
    // Rendered ahead of the tap once the entrance animation is done.
    expect(rendered, hasLength(1));
    final state = tester.state(find.byType(RunSummaryOverlay));
    await _pumpOverlay(
      tester,
      share: share,
      renderCard: render,
      progress: const CampProgress.initial().withSticker('pennant', 5),
      theme: CampTheme.night,
    );
    // The same summary state re-renders ahead of the tap, once.
    expect(
      identical(tester.state(find.byType(RunSummaryOverlay)), state),
      isTrue,
    );
    expect(rendered, hasLength(2));
    await _tapButton(tester, 'Save card');
    expect(rendered, hasLength(2));
    expect(rendered.last.theme, CampTheme.night);
    expect(rendered.last.stickerSlots.at(5), 'pennant');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('a failed render is retried on the next tap', (tester) async {
    final share = _FakeShare();
    var calls = 0;
    await _pumpOverlay(
      tester,
      share: share,
      renderCard: (_) async => ++calls < 3 ? null : _fakePng,
    );
    await _tapButton(tester, 'Save card');
    expect(find.text('Could not save'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await _tapButton(tester, 'Save card');
    expect(find.text('Card saved'), findsOneWidget);
    expect(calls, 3);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('share failures only show a short toast', (tester) async {
    await _pumpOverlay(
      tester,
      share: _FakeShare(throws: true),
      renderCard: (_) async => throw StateError('render'),
    );
    await _tapButton(tester, 'Copy result');
    expect(find.text('Could not copy'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await _tapButton(tester, 'Save card');
    expect(find.text('Could not save'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await _tapButton(tester, 'Share');
    expect(find.text('Could not share'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
    expect(find.text('Play again'), findsOneWidget);
  });

  testWidgets('a card that cannot render still shares the text', (
    tester,
  ) async {
    final share = _FakeShare(saveOk: false);
    await _pumpOverlay(tester, share: share, renderCard: (_) async => null);
    await _tapButton(tester, 'Save card');
    expect(find.text('Could not save'), findsOneWidget);
    expect(share.saved, isEmpty);
    await tester.pump(const Duration(seconds: 3));
    await _tapButton(tester, 'Share');
    expect(share.shared.single.$2, isNull);
    expect(find.text('Could not share'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('a refused clipboard says Could not copy', (tester) async {
    await _pumpOverlay(
      tester,
      share: _FakeShare(copyOk: false),
      renderCard: (_) async => _fakePng,
    );
    await _tapButton(tester, 'Copy result');
    expect(find.text('Could not copy'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('a cancelled share sheet shows nothing', (tester) async {
    await _pumpOverlay(
      tester,
      share: _FakeShare(shareStatus: ShareStatus.cancelled),
      renderCard: (_) async => _fakePng,
    );
    await _tapButton(tester, 'Share');
    expect(find.text('Could not share'), findsNothing);
  });

  test('share text uses the camp name and level', () {
    expect(
      resultShareText(score: 1234, highestTier: 8, level: 7, link: 'L'),
      'I scored 1234 in MergeCamp! Top camp: Star Observatory, camp Lv 7. L',
    );
  });

  group('result card', () {
    final data = ResultCardData(
      score: 4321,
      best: 4321,
      isNewBest: true,
      highestTier: 5,
      level: 4,
      board: [for (var i = 0; i < 16; i++) i % 3 == 0 ? null : 1 + i % 8],
      stickerSlots: const StickerSlots.empty()
          .put('pennant', 0)
          .put('pine-tree', 4)
          .put('acorn', 7),
      theme: CampTheme.autumn,
    );

    testWidgets('renders a PNG', (tester) async {
      final png = await tester.runAsync(() => renderResultCard(data));
      expect(png, isNotNull);
      expect(png!.length, greaterThan(1000));
      expect(png.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
    });

    testWidgets('uses the injected encoder on a full size image', (
      tester,
    ) async {
      final sizes = <(int, int)>[];
      final png = await tester.runAsync(
        () => renderResultCard(
          data,
          encode: (ui.Image image) async {
            sizes.add((image.width, image.height));
            return _fakePng;
          },
        ),
      );
      expect(png, _fakePng);
      expect(sizes, [(1080, 1350)]);
    });

    testWidgets('encoder failures give null instead of throwing', (
      tester,
    ) async {
      expect(
        await tester.runAsync(
          () => renderResultCard(data, encode: (_) async => throw 'boom'),
        ),
        isNull,
      );
      expect(
        await tester.runAsync(
          () => renderResultCard(data, encode: (_) async => Uint8List(0)),
        ),
        isNull,
      );
    });

    test('paints every theme and an empty board without errors', () {
      for (final theme in CampTheme.values) {
        final recorder = ui.PictureRecorder();
        paintResultCard(
          Canvas(recorder),
          resultCardSize,
          ResultCardData(
            score: 0,
            best: 0,
            isNewBest: false,
            highestTier: 99,
            level: 30,
            board: const <int?>[],
            stickerSlots: const StickerSlots.empty(),
            theme: theme,
          ),
        );
        recorder.endRecording().dispose();
      }
    });
  });
}
