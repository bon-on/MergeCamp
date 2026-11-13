// Run with: flutter test --platform chrome test/web
@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_camp/src/meta/daily_camp.dart';

void main() {
  test('seeded random matches the Dart VM values', () {
    final r = SeededRandom(1);
    expect(
      [for (var i = 0; i < 6; i++) r.nextUint32()],
      [3677456184, 2433263795, 131063100, 1902920200, 3700092254, 2769081358],
    );
    final d = SeededRandom(dailySeed(20000));
    expect(
      [for (var i = 0; i < 8; i++) d.nextInt(23)],
      [21, 19, 4, 17, 12, 9, 10, 17],
    );
    expect(dailySeed(20000), 162184709);
  });
}
