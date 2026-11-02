import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../meta/camp_theme.dart';

/// Colors shared by the scenery, the board and the HUD for one [CampTheme].
///
/// Everything is drawn in code, so this is the single place that decides how
/// a theme looks. Tier card colors stay the same across themes so a camp is
/// always recognizable by color, only the surroundings change.
@immutable
class CampPalette {
  const CampPalette._({
    required this.theme,
    required this.skyTop,
    required this.skyBottom,
    required this.hillFar,
    required this.hillNear,
    required this.treeDark,
    required this.treeLight,
    required this.groundBoard,
    required this.plotEmpty,
    required this.plotEmptyBorder,
    required this.panel,
    required this.panelBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.danger,
    required this.groundPatch,
    required this.groundPatchLight,
  });

  /// Returns the palette for [theme].
  static CampPalette of(CampTheme theme) => switch (theme) {
    CampTheme.summer => _summer,
    CampTheme.autumn => _autumn,
    CampTheme.snow => _snow,
    CampTheme.night => _night,
  };

  final CampTheme theme;

  /// Sky gradient, top of the screen.
  final Color skyTop;

  /// Sky gradient, horizon.
  final Color skyBottom;

  /// Distant hill ridge.
  final Color hillFar;

  /// Near hill ridge and the ground at the bottom of the scenery.
  final Color hillNear;

  /// Pine silhouettes in the foreground.
  final Color treeDark;

  /// Lit side of the foreground trees.
  final Color treeLight;

  /// Board backdrop (the clearing the plots sit on).
  final Color groundBoard;

  /// Empty plot fill.
  final Color plotEmpty;

  /// Empty plot outline.
  final Color plotEmptyBorder;

  /// Semi-opaque card color for HUD panels.
  final Color panel;

  /// Outline of HUD panels.
  final Color panelBorder;

  /// Main text on [panel].
  final Color textPrimary;

  /// Secondary text (labels, hints) on [panel].
  final Color textSecondary;

  /// Buttons and highlights.
  final Color accent;

  /// Warnings (board almost full, game over).
  final Color danger;

  /// Grass (or snow) patch under each tile illustration.
  final Color groundPatch;

  /// Lit top of [groundPatch].
  final Color groundPatchLight;

  /// Text color that reads well on [accent].
  Color get onAccent => const Color(0xFF3A2414);

  /// Card base color for camp [tier] (1..8, clamped).
  Color tierColor(int tier) => _tierColors[(tier - 1).clamp(0, 7)];

  static const List<Color> _tierColors = [
    Color(0xFFB4E09A), // 1 Trail Tent: fresh meadow
    Color(0xFF7F8BD9), // 2 Cook Fire: dusk periwinkle
    Color(0xFFF5D488), // 3 Supply Shed: wheat
    Color(0xFF8FD0EA), // 4 Scout Cabin: clear sky
    Color(0xFFF5A984), // 5 Signal Tower: peach
    Color(0xFFBBA0E6), // 6 Base Lodge: lavender
    Color(0xFF7DD3C0), // 7 Summit Camp: glacier mint
    Color(0xFF34407E), // 8 Star Observatory: night navy
  ];

  static const _summer = CampPalette._(
    theme: CampTheme.summer,
    skyTop: Color(0xFF6FBFE6),
    skyBottom: Color(0xFFDDF3E6),
    hillFar: Color(0xFF9BCFA5),
    hillNear: Color(0xFF6DB27C),
    treeDark: Color(0xFF2E6A4B),
    treeLight: Color(0xFF3F8A5E),
    groundBoard: Color(0xFF4C8A5B),
    plotEmpty: Color(0xFF5E9E69),
    plotEmptyBorder: Color(0xFF80BC85),
    panel: Color(0xF2FFF8EA),
    panelBorder: Color(0xFFE6D3AE),
    textPrimary: Color(0xFF3B2C20),
    textSecondary: Color(0xFF7D6750),
    accent: Color(0xFFFFB546),
    danger: Color(0xFFE5484D),
    groundPatch: Color(0xFF79C26A),
    groundPatchLight: Color(0xFF9AD986),
  );

  static const _autumn = CampPalette._(
    theme: CampTheme.autumn,
    skyTop: Color(0xFF8DBBDB),
    skyBottom: Color(0xFFFBE0BA),
    hillFar: Color(0xFFE6B47C),
    hillNear: Color(0xFFCB8650),
    treeDark: Color(0xFF4B4F2C),
    treeLight: Color(0xFF68703A),
    groundBoard: Color(0xFF8B6240),
    plotEmpty: Color(0xFF9E744D),
    plotEmptyBorder: Color(0xFFC09466),
    panel: Color(0xF2FFF5E6),
    panelBorder: Color(0xFFE8C9A0),
    textPrimary: Color(0xFF3E2A1C),
    textSecondary: Color(0xFF85654A),
    accent: Color(0xFFF59A3C),
    danger: Color(0xFFD9433F),
    groundPatch: Color(0xFFD9A156),
    groundPatchLight: Color(0xFFEBBE74),
  );

  static const _snow = CampPalette._(
    theme: CampTheme.snow,
    skyTop: Color(0xFF9DC2E6),
    skyBottom: Color(0xFFEAF3FB),
    hillFar: Color(0xFFDCE8F3),
    hillNear: Color(0xFFC6D9EA),
    treeDark: Color(0xFF2D5266),
    treeLight: Color(0xFF3E6A80),
    groundBoard: Color(0xFF6E8FAA),
    plotEmpty: Color(0xFF82A2BB),
    plotEmptyBorder: Color(0xFFA9C3D7),
    panel: Color(0xF2F7FBFF),
    panelBorder: Color(0xFFC9DBEA),
    textPrimary: Color(0xFF233746),
    textSecondary: Color(0xFF5F7889),
    accent: Color(0xFF5BB8F0),
    danger: Color(0xFFE5484D),
    groundPatch: Color(0xFFEAF2FA),
    groundPatchLight: Color(0xFFFFFFFF),
  );

  static const _night = CampPalette._(
    theme: CampTheme.night,
    skyTop: Color(0xFF0E1636),
    skyBottom: Color(0xFF34457C),
    hillFar: Color(0xFF2B3B66),
    hillNear: Color(0xFF1F2C50),
    treeDark: Color(0xFF111A33),
    treeLight: Color(0xFF1A2747),
    groundBoard: Color(0xFF24335A),
    plotEmpty: Color(0xFF2F4170),
    plotEmptyBorder: Color(0xFF4B5F96),
    panel: Color(0xEB1A2245),
    panelBorder: Color(0xFF3C4D85),
    textPrimary: Color(0xFFF4F1FF),
    textSecondary: Color(0xFFAEB7DA),
    accent: Color(0xFFFFC857),
    danger: Color(0xFFFF5D6C),
    groundPatch: Color(0xFF3E6E62),
    groundPatchLight: Color(0xFF55897A),
  );
}
