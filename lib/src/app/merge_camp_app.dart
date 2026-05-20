import 'package:flutter/material.dart';

import '../game/merge_camp_screen.dart';

class MergeCampApp extends StatelessWidget {
  const MergeCampApp({super.key});

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
      home: const MergeCampScreen(),
    );
  }
}
