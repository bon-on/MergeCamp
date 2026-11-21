import 'package:shared_preferences/shared_preferences.dart';

/// Tools that get a one-time hint (feature-tool-hints).
enum ToolHint {
  shift(
    1,
    'Shift: tap the button, pick a camp, then a glowing cell to move it.',
  ),
  axe(2, 'Board filling up? Tap Trail Axe, then a camp to clear it.');

  const ToolHint(this.bit, this.text);

  final int bit;
  final String text;
}

/// Which hints this device has shown, as a bit set in `tool_hints_v1`.
class ToolHintStore {
  const ToolHintStore();

  static const String key = 'tool_hints_v1';

  Future<Set<ToolHint>> loadSeen() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final bits = preferences.getInt(key) ?? 0;
      return {
        for (final hint in ToolHint.values)
          if (bits & hint.bit != 0) hint,
      };
    } catch (_) {
      // Unknown: show nothing rather than repeat hints.
      return {...ToolHint.values};
    }
  }

  Future<void> markSeen(ToolHint hint) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final bits = preferences.getInt(key) ?? 0;
      await preferences.setInt(key, bits | hint.bit);
    } catch (_) {
      return;
    }
  }
}
