import 'package:flutter_test/flutter_test.dart';
import 'package:merge_camp/src/game/merge_camp_controller.dart';

/// Places on the first free plot that does not merge, as many times as asked,
/// and returns every tile that was dealt (the upcoming three included).
List<int> _play(MergeCampController c, int placements) {
  final dealt = <int>[...c.previewTiers];
  for (var i = 0; i < placements && !c.isGameOver; i++) {
    final index = c.board.indexOf(null);
    c.place(index);
    dealt.add(c.previewTiers.last);
  }
  return dealt;
}

void main() {
  test('the same day deals the same pieces, other days differ', () {
    final a = _play(MergeCampController(dailyDay: 20000), 20);
    final b = _play(MergeCampController(dailyDay: 20000), 20);
    final c = _play(MergeCampController(dailyDay: 20001), 20);
    expect(a, b);
    expect(a, isNot(c));
  });

  test('the sequence does not depend on where the player places', () {
    final a = MergeCampController(dailyDay: 20000);
    final b = MergeCampController(dailyDay: 20000);
    final dealtA = <int>[...a.previewTiers];
    final dealtB = <int>[...b.previewTiers];
    for (var i = 0; i < 12; i++) {
      a.place(a.board.indexOf(null));
      dealtA.add(a.previewTiers.last);
      b.place(b.board.lastIndexOf(null));
      dealtB.add(b.previewTiers.last);
    }
    expect(dealtA, dealtB);
  });

  test('restart replays the daily sequence and free play leaves it', () {
    final c = MergeCampController(dailyDay: 20000);
    final first = _play(c, 10);
    c.restart();
    expect(c.dailyDay, 20000);
    expect(_play(c, 10), first);
    c.startFreePlay();
    expect(c.dailyDay, isNull);
    c.startDaily(20001);
    expect(c.dailyDay, 20001);
  });

  test('a saved daily run continues the same sequence', () {
    final reference = MergeCampController(dailyDay: 20000);
    final expected = _play(reference, 14);

    final c = MergeCampController(dailyDay: 20000);
    _play(c, 6);
    final snapshot = c.toSnapshot();
    expect(snapshot['daily'], {'day': 20000, 'draws': 3 + 6});

    final restored = MergeCampController();
    expect(restored.restoreSnapshot(snapshot), isTrue);
    expect(restored.dailyDay, 20000);
    final dealt = <int>[...restored.previewTiers];
    for (var i = 0; i < 8; i++) {
      restored.place(restored.board.indexOf(null));
      dealt.add(restored.previewTiers.last);
    }
    // The restored run's sequence equals the uninterrupted one.
    expect(dealt, expected.sublist(6, 6 + dealt.length));
  });

  test('malformed daily markers are rejected and old snapshots still load', () {
    final c = MergeCampController(dailyDay: 20000);
    _play(c, 4);
    final good = c.toSnapshot();
    for (final bad in <Object?>[
      'x',
      {'day': -1, 'draws': 7},
      {'day': 20000, 'draws': 5},
      {'day': 20000},
      {'day': 1 << 20, 'draws': 7},
    ]) {
      final snapshot = Map<String, dynamic>.of(good)..['daily'] = bad;
      expect(MergeCampController().restoreSnapshot(snapshot), isFalse);
    }

    final free = MergeCampController();
    _play(free, 4);
    final old = free.toSnapshot();
    expect(old.containsKey('daily'), isFalse);
    final target = MergeCampController(dailyDay: 20000);
    expect(target.restoreSnapshot(old), isTrue);
    expect(target.dailyDay, isNull);
  });
}
