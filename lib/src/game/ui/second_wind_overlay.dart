import 'package:flutter/material.dart';

import '../../art/camp_palette.dart';
import '../../meta/camp_theme.dart';
import 'camp_ui.dart';

/// "Second Wind" card shown when the board locks up and a rewarded ad can
/// bring the run back (feature-second-wind). The run is not settled while it
/// is open. The board underneath gets no input.
class SecondWindOverlay extends StatelessWidget {
  const SecondWindOverlay({
    super.key,
    required this.theme,
    required this.clears,
    required this.onContinue,
    required this.onEnd,
    required this.continueFocus,
    this.busy = false,
  });

  final CampTheme theme;

  /// Camps the continue clears (shown in the text).
  final int clears;
  final VoidCallback onContinue;
  final VoidCallback onEnd;
  final FocusNode continueFocus;

  /// True while the rewarded ad is showing.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final palette = CampPalette.of(theme);
    return Stack(
      children: [
        const ModalBarrier(dismissible: false, color: Color(0x99101A14)),
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: CampPanel(
                  key: const ValueKey('second-wind-card'),
                  palette: palette,
                  padding: const EdgeInsets.all(18),
                  // The buttons stay pinned below the scrolling text so
                  // short landscape phones can always answer the card.
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Icon(
                                Icons.air_rounded,
                                size: 40,
                                color: palette.accent,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Second Wind',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'The camp is jammed! Watch a short video to clear '
                                '$clears camps and keep playing.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: palette.textSecondary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      CampButton(
                        key: const ValueKey('second-wind-continue'),
                        palette: palette,
                        label: 'Watch video to continue',
                        icon: Icons.play_circle_rounded,
                        focusNode: continueFocus,
                        onPressed: busy ? null : onContinue,
                      ),
                      const SizedBox(height: 10),
                      CampButton(
                        key: const ValueKey('second-wind-end'),
                        palette: palette,
                        label: 'End run',
                        primary: false,
                        onPressed: busy ? null : onEnd,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
