import 'package:flutter_test/flutter_test.dart';
import 'package:merge_camp/src/platform/game_platform.dart';

void main() {
  test('GamePix platform blocks result upload', () {
    const platform = NoopGamePlatform.gamePix();
    expect(platform.allowsResultRegistration, isFalse);
  });

  test('default no-op platform keeps Pages and mobile behaviour', () {
    const platform = NoopGamePlatform();
    expect(platform.allowsResultRegistration, isTrue);
  });

  test('GamePix platform is inert and never throws', () async {
    const platform = NoopGamePlatform.gamePix();
    await platform.initialize();
    platform.gameplayStart();
    platform.gameplayStop();
  });
}
