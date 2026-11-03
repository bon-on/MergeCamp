import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../art/camp_palette.dart';
import '../art/camp_tile_art.dart';
import '../meta/camp_theme.dart';

/// Remembers whether the first-run "How to play" card has been dismissed.
///
/// Storage failures never break play: a read failure reports "not seen" (the
/// tutorial is shown) and a write failure is ignored. Tests subclass this.
class HowToPlayStore {
  const HowToPlayStore();

  static const String seenKey = 'tutorial_seen_v1';

  Future<bool> loadSeen() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      return preferences.getBool(seenKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> markSeen() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(seenKey, true);
    } catch (_) {
      return;
    }
  }
}

class HowToPlayStep {
  const HowToPlayStep({required this.icon, required this.text, this.tiers});

  final IconData icon;
  final String text;

  /// Optional camp tiers drawn as a small illustration instead of [icon]
  /// (the last one is shown as the merge result).
  final List<int>? tiers;
}

/// Full-screen scrim plus a "How to play" card. Swallows every key event and
/// pointer event so nothing reaches the game underneath while it is open.
class HowToPlayOverlay extends StatefulWidget {
  const HowToPlayOverlay({
    super.key,
    required this.steps,
    required this.onClose,
    this.theme = CampTheme.summer,
    this.onPlay,
  });

  final List<HowToPlayStep> steps;

  /// Camp theme for the card colors.
  final CampTheme theme;

  /// Called when the player presses Skip, Play or Escape.
  final VoidCallback onClose;

  /// Finishing the explanation may start the first-run practice.
  final VoidCallback? onPlay;

  @override
  State<HowToPlayOverlay> createState() => _HowToPlayOverlayState();
}

class _HowToPlayOverlayState extends State<HowToPlayOverlay> {
  int _index = 0;
  final FocusNode _focusNode = FocusNode(debugLabel: 'HowToPlayOverlay');

  @override
  void initState() {
    super.initState();
    // The game's own Focus already holds primary focus, so autofocus alone
    // would not move it here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  bool get _isLast => _index >= widget.steps.length - 1;

  void _next() {
    if (_isLast) {
      (widget.onPlay ?? widget.onClose)();
    } else {
      setState(() => _index += 1);
    }
  }

  void _previous() {
    if (_index > 0) {
      setState(() => _index -= 1);
    }
  }

  static final Set<LogicalKeyboardKey> _cardKeys = {
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
    LogicalKeyboardKey.space,
    LogicalKeyboardKey.escape,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.arrowLeft,
  };

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    // Only the card's own keys are handled here. Everything else (Tab, F5,
    // Cmd/Ctrl shortcuts) bubbles up: the game screen blocks game keys while
    // the card is open and leaves browser/OS shortcuts alone.
    if (!_cardKeys.contains(key) ||
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isAltPressed) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent) {
      if (key == LogicalKeyboardKey.escape) {
        widget.onClose();
      } else if (key == LogicalKeyboardKey.arrowRight) {
        if (!_isLast) _next();
      } else if (key == LogicalKeyboardKey.arrowLeft) {
        _previous();
      } else {
        _next();
      }
    }
    // Repeats and key-ups of card keys are swallowed without acting.
    return KeyEventResult.handled;
  }

  Widget _illustration(HowToPlayStep step, CampPalette palette) {
    final tiers = step.tiers;
    if (tiers == null || tiers.isEmpty) {
      return Center(
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: palette.accent,
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: Icon(step.icon, size: 34, color: palette.onAccent),
        ),
      );
    }
    final inputs = tiers.length > 1
        ? tiers.sublist(0, tiers.length - 1)
        : tiers;
    return SizedBox(
      height: 64,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          for (final tier in inputs) ...<Widget>[
            SizedBox.square(
              dimension: 46,
              child: CampTileArt(
                tier: tier,
                theme: widget.theme,
                animate: false,
              ),
            ),
            const SizedBox(width: 4),
          ],
          if (tiers.length > 1) ...<Widget>[
            Icon(Icons.arrow_forward_rounded, color: palette.textSecondary),
            const SizedBox(width: 4),
            SizedBox.square(
              dimension: 62,
              child: CampTileArt(
                tier: tiers.last,
                theme: widget.theme,
                animate: false,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = CampPalette.of(widget.theme);
    final step = widget.steps[_index];
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: Stack(
        children: <Widget>[
          const ModalBarrier(dismissible: false, color: Color(0x99101A14)),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Material(
                    color: palette.panel,
                    elevation: 10,
                    shadowColor: const Color(0x66000000),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                      side: BorderSide(color: palette.panelBorder, width: 1.5),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(22, 20, 22, 14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            'How to play',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _illustration(step, palette),
                          const SizedBox(height: 16),
                          Text(
                            step.text,
                            key: const ValueKey('how-to-play-text'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 15,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              for (var i = 0; i < widget.steps.length; i++)
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  width: i == _index ? 20 : 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    color: i == _index
                                        ? palette.accent
                                        : palette.textSecondary.withValues(
                                            alpha: 0.3,
                                          ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: <Widget>[
                              TextButton(
                                onPressed: widget.onClose,
                                style: TextButton.styleFrom(
                                  foregroundColor: palette.textSecondary,
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                child: const Text('Skip'),
                              ),
                              const Spacer(),
                              FilledButton(
                                onPressed: _next,
                                style: FilledButton.styleFrom(
                                  backgroundColor: palette.accent,
                                  foregroundColor: palette.onAccent,
                                  minimumSize: const Size(110, 46),
                                  textStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(_isLast ? 'Play' : 'Next'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
