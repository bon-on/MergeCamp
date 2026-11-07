import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_camp/src/meta/camp_progress.dart';
import 'package:merge_camp/src/meta/camp_theme.dart';
import 'package:merge_camp/src/meta/stickers.dart';

/// Total XP that reaches exactly [level].
int xpForLevel(int level) {
  var total = 0;
  for (var l = 1; l < level; l++) {
    total += CampProgress.xpToAdvance(l);
  }
  return total;
}

CampProgress atLevel(
  int level, {
  StickerSlots slots = const StickerSlots.empty(),
  int? seen,
}) => CampProgress(
  bestScore: 10,
  discoveredTiers: const {1},
  totalXp: xpForLevel(level),
  selectedTheme: CampTheme.summer,
  stickerSlots: slots,
  stickersSeen: seen,
);

RunSummary runWithXp(int xp) =>
    RunSummary(score: xp * 10, highestTier: 1, bestChain: 0, placements: 1);

StickerSlots slotsOf(Map<int, String> map) {
  var slots = const StickerSlots.empty();
  map.forEach((slot, id) => slots = slots.put(id, slot));
  return slots;
}

void main() {
  group('catalog', () {
    test('25 unique stickers in level order, rare every fifth', () {
      expect(Sticker.catalog, hasLength(25));
      expect(Sticker.catalog.map((s) => s.id).toSet(), hasLength(25));
      for (var i = 0; i < 25; i++) {
        expect(Sticker.catalog[i].level, i + 1);
        expect(Sticker.forLevel(i + 1), same(Sticker.catalog[i]));
        expect(Sticker.byId(Sticker.catalog[i].id), same(Sticker.catalog[i]));
      }
      expect(
        [
          for (final s in Sticker.catalog)
            if (s.rare) s.level,
        ],
        [5, 10, 15, 20, 25],
      );
      expect(Sticker.forLevel(0), isNull);
      expect(Sticker.forLevel(26), isNull);
      expect(Sticker.forLevel(1)!.name, 'Pennant');
      expect(Sticker.forLevel(25)!.name, 'Star Badge');
      for (final s in Sticker.catalog) {
        expect(RegExp(r'^[ -~]+$').hasMatch(s.name), isTrue);
      }
    });

    test('a level L progress owns exactly min(L, 25) stickers', () {
      for (final level in [1, 2, 9, 24, 25, 26, 40]) {
        final p = atLevel(level);
        expect(p.level, level);
        expect(p.ownedStickers, hasLength(level < 25 ? level : 25));
      }
    });
  });

  group('slots', () {
    test('put, swap, move and remove keep one sticker per slot', () {
      var s = const StickerSlots.empty().put('pennant', 0);
      expect(s.at(0), 'pennant');
      // Tray sticker onto an occupied slot: the occupant goes to the tray.
      s = s.put('acorn', 0);
      expect(s.at(0), 'acorn');
      expect(s.slotOf('pennant'), isNull);
      s = s.put('pennant', 4);
      // Slot sticker onto an occupied slot: the two swap.
      s = s.put('acorn', 4);
      expect(s.at(4), 'acorn');
      expect(s.at(0), 'pennant');
      // Slot sticker onto an empty slot: it moves.
      s = s.put('acorn', 9);
      expect(s.at(9), 'acorn');
      expect(s.at(4), isNull);
      expect(s.length, 2);
      s = s.remove(9);
      expect(s.slotOf('acorn'), isNull);
      expect(identical(s.remove(5), s), isTrue);
      expect(identical(s.put('nope', 1), s), isTrue);
      expect(identical(s.put('acorn', 10), s), isTrue);
      expect(identical(s.put('pennant', 0), s), isTrue);
    });

    test('json round trip', () {
      final s = slotsOf({0: 'pennant', 3: 'acorn', 9: 'spark'});
      final back = StickerSlots.fromJson(
        jsonDecode(jsonEncode(s.toJson())),
        level: 5,
      );
      expect(back, s);
      expect(back.signature, '0=pennant,3=acorn,9=spark');
    });

    test('parser drops unowned, out of range and repeated stickers', () {
      final s = StickerSlots.fromJson({
        '0': 'pennant',
        '1': 'star-badge', // not owned at level 3
        '2': 'acorn',
        '5': 'pennant', // repeat: slot 0 wins
        '10': 'pine-tree', // out of range
        '-1': 'pine-tree',
        '01': 'pine-tree',
        'x': 'pine-tree',
        '3': 7,
        '4': 'unknown',
        '6': 'pine-tree',
      }, level: 3);
      expect(s.toJson(), {'0': 'pennant', '2': 'acorn', '6': 'pine-tree'});
      for (final bad in [null, 'x', 3, <Object>[], <String, Object>{}]) {
        expect(StickerSlots.fromJson(bad, level: 25).isEmpty, isTrue);
      }
    });
  });

  group('progress', () {
    test('sticker fields survive json and tolerate corrupt values', () {
      final p = atLevel(6).withSticker('marshmallow', 2).withStickersSeen();
      final back = CampProgress.fromJson(jsonDecode(jsonEncode(p.toJson())));
      expect(back.stickerSlots.at(2), 'marshmallow');
      expect(back.stickersSeen, 6);
      expect(back.totalXp, p.totalXp);

      final json = p.toJson()
        ..['stickerSlots'] = 'garbage'
        ..['stickersSeen'] = 'x';
      final broken = CampProgress.fromJson(json);
      expect(broken.stickerSlots.isEmpty, isTrue);
      expect(broken.stickersSeen, isNull);
      expect(broken.level, 6);

      final legacy = CampProgress.fromJson({'totalXp': xpForLevel(4)});
      expect(legacy.stickerSlots.isEmpty, isTrue);
      expect(legacy.stickersSeen, isNull);
    });

    test('only owned stickers can be stuck', () {
      final p = atLevel(2);
      expect(identical(p.withSticker('acorn', 0), p), isTrue);
      final placed = p.withSticker('pine-tree', 0);
      expect(placed.stickerSlots.at(0), 'pine-tree');
      expect(placed.stickerTray.map((s) => s.id), ['pennant']);
      expect(placed.withoutSticker(0).stickerSlots.isEmpty, isTrue);
    });

    test('existing players are told about their stickers once', () {
      final legacy = atLevel(7);
      expect(legacy.unseenStickerCount, 7);
      final seen = legacy.withStickersSeen();
      expect(seen.stickersSeen, 7);
      expect(seen.unseenStickerCount, 0);
      // Nothing is auto-placed for levels reached before stickers existed.
      expect(seen.stickerSlots.isEmpty, isTrue);
      expect(seen.stickerTray, hasLength(7));
      // A brand-new player is not told anything.
      expect(const CampProgress.initial().unseenStickerCount, 0);
      expect(atLevel(30, seen: 3).unseenStickerCount, 22);
    });

    test('a level-up sticks the new sticker on the first empty slot', () {
      final p = atLevel(2, seen: 2).withSticker('pennant', 0);
      final need = p.xpForNextLevel - p.xpIntoLevel;
      final outcome = p.applyRun(runWithXp(need));
      expect(outcome.levelAfter, 3);
      expect(outcome.newStickers, hasLength(1));
      expect(outcome.newStickers.single.sticker.id, 'acorn');
      expect(outcome.newStickers.single.slot, 1);
      expect(outcome.progress.stickerSlots.at(1), 'acorn');
      expect(outcome.progress.stickersSeen, 3);
      // XP and the level curve are unchanged by stickers.
      expect(outcome.xpGained, need);

      final quiet = p.applyRun(runWithXp(1));
      expect(quiet.newStickers, isEmpty);
      expect(quiet.progress.stickerSlots, p.stickerSlots);
    });

    test('several levels at once are placed in level order', () {
      final p = atLevel(1, seen: 1);
      final xp = xpForLevel(4) - p.totalXp;
      final outcome = p.applyRun(runWithXp(xp));
      expect(outcome.levelAfter, 4);
      expect(
        [for (final a in outcome.newStickers) (a.sticker.id, a.slot)],
        [('pine-tree', 0), ('acorn', 1), ('lantern', 2)],
      );
    });

    test('with every slot taken a new sticker stays in the tray', () {
      var p = atLevel(10, seen: 10);
      for (var slot = 0; slot < StickerSlots.count; slot++) {
        p = p.withSticker(Sticker.catalog[slot].id, slot);
      }
      final need = p.xpForNextLevel - p.xpIntoLevel;
      final outcome = p.applyRun(runWithXp(need));
      expect(outcome.levelAfter, 11);
      expect(outcome.newStickers.single.sticker.id, 'binoculars');
      expect(outcome.newStickers.single.slot, isNull);
      expect(outcome.progress.stickerSlots, p.stickerSlots);
      expect(outcome.progress.stickerTray.map((s) => s.id), ['binoculars']);
    });

    test('levels past the catalog award no sticker', () {
      final p = atLevel(25, seen: 25);
      final need = p.xpForNextLevel - p.xpIntoLevel;
      final outcome = p.applyRun(runWithXp(need));
      expect(outcome.levelAfter, 26);
      expect(outcome.newStickers, isEmpty);
    });

    test('active run snapshots keep the sticker fields', () {
      final p = atLevel(3).withSticker('acorn', 5).withStickersSeen();
      final live = p.withActiveRun({'version': 1});
      expect(live.stickerSlots.at(5), 'acorn');
      expect(live.stickersSeen, 3);
      expect(live.toJson()['activeRun'], {'version': 1});
      final ended = live.applyRun(runWithXp(0)).progress;
      expect(ended.activeRun, isNull);
      expect(ended.stickerSlots.at(5), 'acorn');
    });

    test('saved sticker data stays small', () {
      var p = atLevel(25).withStickersSeen();
      for (var slot = 0; slot < StickerSlots.count; slot++) {
        p = p.withSticker(Sticker.catalog[24 - slot].id, slot);
      }
      final json = p.toJson();
      final size = jsonEncode({
        'stickerSlots': json['stickerSlots'],
        'stickersSeen': json['stickersSeen'],
      }).length;
      expect(size, lessThan(1024));
    });
  });
}
