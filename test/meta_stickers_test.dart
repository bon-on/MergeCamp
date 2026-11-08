import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_camp/src/art/sticker_art.dart';
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
      s = s.put('acorn', 15);
      expect(s.at(15), 'acorn');
      expect(s.at(4), isNull);
      expect(s.length, 2);
      s = s.remove(15);
      expect(s.slotOf('acorn'), isNull);
      expect(identical(s.remove(5), s), isTrue);
      expect(identical(s.put('nope', 1), s), isTrue);
      expect(identical(s.put('acorn', 16), s), isTrue);
      expect(identical(s.put('acorn', -1), s), isTrue);
      expect(identical(s.put('pennant', 0), s), isTrue);
    });

    test('json round trip', () {
      final s = slotsOf({0: 'pennant', 3: 'acorn', 9: 'spark', 15: 'mug'});
      final back = StickerSlots.fromJson(
        jsonDecode(jsonEncode(s.toJson())),
        level: 8,
      );
      expect(back, s);
      expect(back.signature, '0=pennant,3=acorn,9=spark,15=mug');
    });

    test('parser drops unowned, out of range and repeated stickers', () {
      final s = StickerSlots.fromJson({
        '0': 'pennant',
        '1': 'star-badge', // not owned at level 3
        '2': 'acorn',
        '5': 'pennant', // repeat: slot 0 wins
        '16': 'pine-tree', // out of range
        '100': 'pine-tree',
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
      // A marker above the level (another device) is never lowered.
      final ahead = atLevel(3, seen: 9);
      expect(identical(ahead.withStickersSeen(), ahead), isTrue);
      expect(ahead.unseenStickerCount, 0);
    });

    test('a brand-new player gets the Pennant stuck on the first slot', () {
      final welcomed = const CampProgress.initial().withStickersSeen();
      expect(welcomed.stickersSeen, 1);
      expect(welcomed.stickerSlots.toJson(), {'0': 'pennant'});
      expect(identical(welcomed.withStickersSeen(), welcomed), isTrue);
      final back = CampProgress.fromJson(
        jsonDecode(jsonEncode(welcomed.toJson())),
      );
      expect(back.stickerSlots.at(0), 'pennant');
      expect(back.stickersSeen, 1);
      expect(identical(back.withStickersSeen(), back), isTrue);
      // A first-ever load from storage (no stickersSeen) is the same.
      final loaded = CampProgress.fromJson(
        <String, Object>{},
      ).withStickersSeen();
      expect(loaded.stickerSlots.at(0), 'pennant');
      // Returning players keep theirs in the tray, even at level 1.
      final returning = atLevel(1).withStickersSeen();
      expect(returning.stickerSlots.isEmpty, isTrue);
      expect(returning.stickersSeen, 1);
      // Reaching Lv2 then sticks the Pine Tree next to the Pennant.
      final outcome = welcomed.applyRun(runWithXp(CampProgress.xpToAdvance(1)));
      expect(outcome.newStickers.single.slot, 1);
      expect(outcome.progress.stickerSlots.toJson(), {
        '0': 'pennant',
        '1': 'pine-tree',
      });
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
      var p = atLevel(16, seen: 16);
      for (var slot = 0; slot < StickerSlots.count; slot++) {
        p = p.withSticker(Sticker.catalog[slot].id, slot);
      }
      expect(p.stickerSlots.length, 16);
      expect(p.stickerSlots.firstEmpty, isNull);
      final need = p.xpForNextLevel - p.xpIntoLevel;
      final outcome = p.applyRun(runWithXp(need));
      expect(outcome.levelAfter, 17);
      expect(outcome.newStickers.single.sticker.id, 'canoe');
      expect(outcome.newStickers.single.slot, isNull);
      expect(outcome.progress.stickerSlots, p.stickerSlots);
      expect(outcome.progress.stickerTray.map((s) => s.id), ['canoe']);
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

  group('slot layout migration', () {
    /// A ten-slot layout save as written before the 16-slot layout: no
    /// `stickerSlotsVersion`, slots 0-2 above, 3-5 below, 6-7 left, 8-9 right.
    Map<String, Object?> legacySave(Map<String, Object?> slots, int level) => {
      'bestScore': 10,
      'discoveredTiers': [1],
      'totalXp': xpForLevel(level),
      'selectedTheme': 'summer',
      'stickerSlots': slots,
      'stickersSeen': level,
    };

    const legacyFull = {
      '0': 'pennant',
      '1': 'pine-tree',
      '2': 'acorn',
      '3': 'lantern',
      '4': 'spark',
      '5': 'marshmallow',
      '6': 'compass',
      '7': 'mug',
      '8': 'hiking-boot',
      '9': 'moon',
    };

    String side(int slot) {
      final c = StickerSlotGeometry.center(slot, 100, 10);
      if (c.dy < 0) return 'top';
      if (c.dy > 100) return 'bottom';
      return c.dx < 0 ? 'left' : 'right';
    }

    test('the new layout has 5 above, 5 below, 3 left and 3 right', () {
      final sides = [for (var i = 0; i < StickerSlots.count; i++) side(i)];
      expect(sides, [
        ...List.filled(5, 'top'),
        ...List.filled(5, 'bottom'),
        ...List.filled(3, 'left'),
        ...List.filled(3, 'right'),
      ]);
      for (var i = 0; i < StickerSlots.count; i++) {
        expect(StickerSlotGeometry.isSide(i), i >= 10);
      }
      // Rows run left to right and sides top to bottom.
      for (final run in const [
        [0, 1, 2, 3, 4],
        [5, 6, 7, 8, 9],
      ]) {
        final xs = [
          for (final i in run) StickerSlotGeometry.center(i, 100, 10).dx,
        ];
        expect(xs, orderedEquals([...xs]..sort()));
      }
      for (final run in const [
        [10, 11, 12],
        [13, 14, 15],
      ]) {
        final ys = [
          for (final i in run) StickerSlotGeometry.center(i, 100, 10).dy,
        ];
        expect(ys, orderedEquals([...ys]..sort()));
      }
      expect(StickerSlots.legacySlotMap, hasLength(StickerSlots.legacyCount));
      expect(StickerSlots.legacySlotMap.toSet(), hasLength(10));
    });

    test('a full ten-slot save keeps every sticker on its side', () {
      final p = CampProgress.fromJson(
        jsonDecode(jsonEncode(legacySave(legacyFull, 10))),
      );
      expect(p.stickerSlots.toJson(), {
        '1': 'pennant',
        '2': 'pine-tree',
        '3': 'acorn',
        '6': 'lantern',
        '7': 'spark',
        '8': 'marshmallow',
        '10': 'compass',
        '12': 'mug',
        '13': 'hiking-boot',
        '15': 'moon',
      });
      // Old slot sides: 0-2 top, 3-5 bottom, 6-7 left, 8-9 right.
      const oldSides = [
        'top',
        'top',
        'top',
        'bottom',
        'bottom',
        'bottom',
        'left',
        'left',
        'right',
        'right',
      ];
      for (var old = 0; old < 10; old++) {
        final id = legacyFull['$old']!;
        expect(side(p.stickerSlots.slotOf(id)!), oldSides[old], reason: id);
      }
      expect(p.stickerSlots.length, 10);
      expect(p.stickerTray, isEmpty);
      // The next level-up fills the free left end of the top row.
      final outcome = p.applyRun(runWithXp(p.xpForNextLevel - p.xpIntoLevel));
      expect(outcome.newStickers.single.sticker.id, 'binoculars');
      expect(outcome.newStickers.single.slot, 0);
    });

    test('a migrated save round trips without moving again', () {
      final migrated = CampProgress.fromJson(legacySave(legacyFull, 10));
      final json = jsonDecode(jsonEncode(migrated.toJson())) as Map;
      expect(json['stickerSlotsVersion'], StickerSlots.layoutVersion);
      final back = CampProgress.fromJson(json);
      expect(back.stickerSlots, migrated.stickerSlots);
      final again = CampProgress.fromJson(
        jsonDecode(jsonEncode(back.toJson())),
      );
      expect(again.stickerSlots, migrated.stickerSlots);
    });

    test('new saves load every slot as is, sides included', () {
      var p = atLevel(16, seen: 16);
      for (var slot = 0; slot < StickerSlots.count; slot++) {
        p = p.withSticker(Sticker.catalog[15 - slot].id, slot);
      }
      final back = CampProgress.fromJson(jsonDecode(jsonEncode(p.toJson())));
      expect(back.stickerSlots, p.stickerSlots);
      expect(back.stickerSlots.at(15), 'pennant');
      expect(back.stickerSlots.at(10), 'marshmallow');
    });

    test('layout version 1 or none migrates, anything else is current', () {
      final slots = {'0': 'pennant', '9': 'acorn'};
      for (final version in [null, 1, 1.0]) {
        final json = legacySave(slots, 3);
        if (version != null) json['stickerSlotsVersion'] = version;
        expect(CampProgress.fromJson(json).stickerSlots.toJson(), {
          '1': 'pennant',
          '15': 'acorn',
        }, reason: '$version');
      }
      for (final version in [2, 3, 'x', <Object>[], true]) {
        final json = legacySave(slots, 3)..['stickerSlotsVersion'] = version;
        expect(CampProgress.fromJson(json).stickerSlots.toJson(), {
          '0': 'pennant',
          '9': 'acorn',
        }, reason: '$version');
      }
    });

    test('legacy parsing tolerates bad data like the current one', () {
      final p = CampProgress.fromJson(
        legacySave({
          '0': 'pennant',
          '1': 'star-badge', // not owned at level 3
          '2': 'acorn',
          '5': 'pennant', // repeat: old slot 0 wins
          '10': 'pine-tree', // out of the ten-slot range
          '15': 'pine-tree',
          '-1': 'pine-tree',
          '07': 'pine-tree',
          'x': 'pine-tree',
          '3': 7,
          '4': 'unknown',
          '8': 'pine-tree',
        }, 3),
      );
      expect(p.stickerSlots.toJson(), {
        '1': 'pennant',
        '3': 'acorn',
        '13': 'pine-tree',
      });
      for (final bad in [null, 'x', 3, <Object>[], <String, Object>{}]) {
        final json = legacySave(legacyFull, 10)..['stickerSlots'] = bad;
        expect(CampProgress.fromJson(json).stickerSlots.isEmpty, isTrue);
        expect(
          StickerSlots.fromJson(bad, level: 25, legacy: true).isEmpty,
          isTrue,
        );
      }
    });
  });
}
