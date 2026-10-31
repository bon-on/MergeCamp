import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  const HowToPlayStep({required this.icon, required this.text});

  final IconData icon;
  final String text;
}

/// Full-screen scrim plus a "How to play" card. Swallows every key event and
/// pointer event so nothing reaches the game underneath while it is open.
class HowToPlayOverlay extends StatefulWidget {
  const HowToPlayOverlay({
    super.key,
    required this.steps,
    required this.onClose,
  });

  final List<HowToPlayStep> steps;

  /// Called when the player presses Skip, Play or Escape.
  final VoidCallback onClose;

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
      widget.onClose();
    } else {
      setState(() => _index += 1);
    }
  }

  void _previous() {
    if (_index > 0) {
      setState(() => _index -= 1);
    }
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    // Keep Tab traversal and browser/OS shortcuts working.
    if (key == LogicalKeyboardKey.tab ||
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isAltPressed) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent) {
      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter ||
          key == LogicalKeyboardKey.space) {
        _next();
      } else if (key == LogicalKeyboardKey.escape) {
        widget.onClose();
      } else if (key == LogicalKeyboardKey.arrowRight) {
        if (!_isLast) _next();
      } else if (key == LogicalKeyboardKey.arrowLeft) {
        _previous();
      }
    }
    // Swallow everything else so game keys never fire behind the card.
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final step = widget.steps[_index];
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: Stack(
        children: <Widget>[
          const ModalBarrier(dismissible: false, color: Color(0xB3000000)),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Material(
                    color: theme.colorScheme.surfaceContainerHigh,
                    elevation: 8,
                    borderRadius: BorderRadius.circular(20),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            'How to play',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 14),
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Icon(
                              step.icon,
                              size: 30,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            step.text,
                            key: const ValueKey('how-to-play-text'),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              for (var i = 0; i < widget.steps.length; i++)
                                Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: i == _index
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.outlineVariant,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: <Widget>[
                              TextButton(
                                onPressed: widget.onClose,
                                child: const Text('Skip'),
                              ),
                              const Spacer(),
                              FilledButton(
                                onPressed: _next,
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
