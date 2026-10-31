import 'crazygames_platform.dart';
import 'game_platform.dart';

const bool _crazyGamesBuild = bool.fromEnvironment('CRAZYGAMES');
const bool _gamePixBuild = bool.fromEnvironment('GAMEPIX');

GamePlatform createGamePlatform() {
  if (_crazyGamesBuild) {
    return CrazyGamesPlatform();
  }
  return _gamePixBuild
      ? const NoopGamePlatform.gamePix()
      : const NoopGamePlatform();
}
