import 'package:flutter/material.dart';

import 'src/ads/ad_service.dart';
import 'src/app/merge_camp_app.dart';
import 'src/platform/game_platform.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final platform = createGamePlatform();
  await platform.initialize();
  await AdService.instance.initialize();
  runApp(MergeCampApp(enableAds: true, platform: platform));
}
