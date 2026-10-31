import 'package:flutter/material.dart';

import '../game/how_to_play.dart';
import '../game/merge_camp_screen.dart';
import '../platform/game_platform.dart';

class MergeCampApp extends StatelessWidget {
  const MergeCampApp({
    super.key,
    this.enableAds = false,
    this.platform = const NoopGamePlatform(),
    this.howToPlayStore = const HowToPlayStore(),
  });

  final bool enableAds;
  final GamePlatform platform;
  final HowToPlayStore howToPlayStore;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MergeCamp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF12211A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7DCB6B),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: MergeCampScreen(
        enableAds: enableAds,
        platform: platform,
        howToPlayStore: howToPlayStore,
      ),
    );
  }
}
