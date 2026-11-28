import 'crazygames_platform.dart';
import 'game_platform.dart';
import 'gamepix_platform.dart';

const bool _crazyGamesBuild = bool.fromEnvironment('CRAZYGAMES');
const bool _gamePixBuild = bool.fromEnvironment('GAMEPIX');

/// One conditional over compile-time constants, so each portal bundle keeps
/// only its own adapter (the other one is tree-shaken).
GamePlatform createGamePlatform() => _crazyGamesBuild
    ? CrazyGamesPlatform()
    : _gamePixBuild
    ? GamePixPlatform()
    : const NoopGamePlatform();
