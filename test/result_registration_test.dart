import 'package:flutter_test/flutter_test.dart';
import 'package:merge_camp/result_registration.dart';

void main() {
  test('normalizes names and rejects invalid values', () {
    expect(normalizePlayerName('  Camp   Player  '), 'Camp Player');
    expect(() => normalizePlayerName('   '), throwsFormatException);
    expect(
      () => normalizePlayerName('123456789012345678901'),
      throwsFormatException,
    );
  });

  test('payload preserves the measured value and metric', () {
    expect(
      buildResultPayload(
        gameId: 'game',
        playerName: 'Player',
        metric: 'time',
        value: 42,
      ),
      {
        'p_game_id': 'game',
        'p_player_name': 'Player',
        'p_value': 42,
        'p_metric': 'time',
      },
    );
  });
}
