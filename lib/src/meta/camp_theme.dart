/// Cosmetic camp themes, unlocked by camp level. Themes never change rules.
enum CampTheme {
  summer(requiredLevel: 1, label: 'Summer'),
  autumn(requiredLevel: 3, label: 'Autumn'),
  snow(requiredLevel: 6, label: 'Snow'),
  night(requiredLevel: 10, label: 'Night');

  const CampTheme({required this.requiredLevel, required this.label});

  /// Camp level at which the theme becomes selectable.
  final int requiredLevel;

  /// Short English name shown in the UI.
  final String label;

  /// Parses a stored theme name; unknown values fall back to [summer].
  static CampTheme fromName(String? name) {
    for (final theme in values) {
      if (theme.name == name) return theme;
    }
    return summer;
  }
}
