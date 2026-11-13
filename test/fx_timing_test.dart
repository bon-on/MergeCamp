import 'package:flutter_test/flutter_test.dart';
import 'package:merge_camp/src/game/ui/board_fx.dart';

void main() {
  test(
    'a single merge lands within 220 ms and chain steps add at most 150 ms',
    () {
      expect(
        FxTiming.impact(1),
        lessThanOrEqualTo(const Duration(milliseconds: 220)),
      );
      for (var chain = 1; chain < 6; chain++) {
        final step = FxTiming.impact(chain + 1) - FxTiming.impact(chain);
        expect(step, lessThanOrEqualTo(const Duration(milliseconds: 150)));
      }
    },
  );
}
