import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../art/camp_palette.dart';
import '../../art/camp_tile_art.dart';
import '../../art/sticker_art.dart';
import '../../meta/camp_progress.dart';
import '../../meta/camp_theme.dart';
import '../merge_camp_controller.dart';
import 'camp_ui.dart';

/// Facts shown on the game over card.
class RunReport {
  const RunReport({
    required this.score,
    required this.highestTier,
    required this.bestChain,
    required this.missionsCompleted,
    this.outcome,
  });

  final int score;
  final int highestTier;
  final int bestChain;
  final int missionsCompleted;

  /// Progress change of this run; null if it could not be applied.
  final RunOutcome? outcome;
}

/// "Camp jammed!" summary with score count-up, best, stats and the XP bar.
/// The board underneath gets no input while this is open.
class RunSummaryOverlay extends StatefulWidget {
  const RunSummaryOverlay({
    super.key,
    required this.report,
    required this.theme,
    required this.onPlayAgain,
    required this.onAlbum,
    required this.onDecorate,
    required this.playAgainFocus,
    this.busy = false,
    this.animateArt = true,
  });

  final RunReport report;
  final CampTheme theme;
  final VoidCallback onPlayAgain;
  final VoidCallback onAlbum;
  final VoidCallback onDecorate;

  /// Owned by the screen so it can refocus the button after the album.
  final FocusNode playAgainFocus;

  /// True while the run break ad is showing.
  final bool busy;
  final bool animateArt;

  @override
  State<RunSummaryOverlay> createState() => _RunSummaryOverlayState();
}

class _RunSummaryOverlayState extends State<RunSummaryOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..forward();

  @override
  void initState() {
    super.initState();
    // The board's Focus holds primary focus, so autofocus alone would not
    // move it to the button.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.playAgainFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _interval(
    double begin,
    double end, [
    Curve curve = Curves.easeOutCubic,
  ]) {
    final t = ((_controller.value - begin) / (end - begin)).clamp(0.0, 1.0);
    return curve.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    final palette = CampPalette.of(widget.theme);
    final report = widget.report;
    final outcome = report.outcome;
    return Stack(
      children: [
        const ModalBarrier(dismissible: false, color: Color(0x99101A14)),
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final p = _interval(0, 0.18, Curves.easeOutBack);
                    return Opacity(
                      opacity: _interval(0, 0.1),
                      child: Transform.scale(
                        scale: 0.85 + 0.15 * p,
                        child: child,
                      ),
                    );
                  },
                  child: Material(
                    type: MaterialType.transparency,
                    child: CampPanel(
                      palette: palette,
                      radius: 28,
                      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                      child: SingleChildScrollView(
                        child: AnimatedBuilder(
                          animation: _controller,
                          builder: (context, _) =>
                              _content(context, palette, report, outcome),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _content(
    BuildContext context,
    CampPalette palette,
    RunReport report,
    RunOutcome? outcome,
  ) {
    final shownScore = (report.score * _interval(0.08, 0.45)).round();
    final isNewBest = outcome?.isNewBest ?? false;
    final best = outcome == null
        ? report.score
        : math.max(outcome.previousBest, report.score);
    final bestShown = _interval(0.4, 0.5);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Camp jammed!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 30,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          'No empty plots and no Trail Axe left.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        PanelCaption('Score', palette: palette),
        Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatScore(shownScore),
              key: const ValueKey('summary-score'),
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 54,
                height: 1.05,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 4,
          children: [
            Text(
              'Best ${formatScore(best)}',
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (isNewBest) ...[
              const SizedBox(width: 10),
              Opacity(
                opacity: bestShown,
                child: Transform.scale(
                  scale: 0.6 + 0.4 * Curves.easeOutBack.transform(bestShown),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: palette.danger,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'New best!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              flex: 5,
              child: _Stat(
                palette: palette,
                caption: 'Top camp',
                leading: SizedBox.square(
                  dimension: 46,
                  child: CampTileArt(
                    tier: report.highestTier,
                    theme: widget.theme,
                    animate: widget.animateArt,
                  ),
                ),
                value: MergeCampController.campTierName(report.highestTier),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: _Stat(
                palette: palette,
                caption: 'Chain',
                value: report.bestChain <= 0 ? '-' : 'x${report.bestChain}',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: _Stat(
                palette: palette,
                caption: 'Missions',
                value: '${report.missionsCompleted}',
              ),
            ),
          ],
        ),
        if (outcome != null) ...[
          const SizedBox(height: 14),
          _xpSection(palette, outcome),
        ],
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: CampButton(
                palette: palette,
                label: 'Album',
                icon: Icons.collections_bookmark_rounded,
                primary: false,
                onPressed: widget.onAlbum,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: CampButton(
                palette: palette,
                label: 'Decorate',
                icon: Icons.auto_awesome_rounded,
                primary: false,
                onPressed: widget.onDecorate,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        CampButton(
          palette: palette,
          label: 'Play again',
          icon: Icons.replay_rounded,
          focusNode: widget.playAgainFocus,
          onPressed: widget.busy ? null : widget.onPlayAgain,
        ),
        const SizedBox(height: 6),
        Text(
          'Enter or R to play again',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _xpSection(CampPalette palette, RunOutcome outcome) {
    final afterXp = outcome.progress.totalXp;
    final beforeXp = math.max(0, afterXp - outcome.xpGained);
    final t = _interval(0.45, 0.9, Curves.easeInOutCubic);
    final shown = CampProgress(
      bestScore: 0,
      discoveredTiers: const <int>{1},
      totalXp: (beforeXp + (afterXp - beforeXp) * t).round(),
      selectedTheme: CampTheme.summer,
    );
    final leveledUp = shown.level > outcome.levelBefore;
    final levelUpShown = leveledUp
        ? _interval(0.88, 1, Curves.easeOutBack)
        : 0.0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.textSecondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              LevelBadge(palette: palette, level: shown.level, size: 42),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: PanelCaption('Camp XP', palette: palette),
                        ),
                        Text(
                          '+${outcome.xpGained} XP',
                          key: const ValueKey('summary-xp'),
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    CampProgressBar(
                      palette: palette,
                      value: shown.xpForNextLevel == 0
                          ? 0
                          : shown.xpIntoLevel / shown.xpForNextLevel,
                      height: 12,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (outcome.levelAfter > outcome.levelBefore)
            Opacity(
              opacity: levelUpShown.clamp(0.0, 1.0),
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _Chip(
                      palette: palette,
                      icon: Icons.arrow_upward_rounded,
                      text: 'Level up! Lv ${outcome.levelAfter}',
                      strong: true,
                    ),
                    for (final theme in outcome.newlyUnlockedThemes)
                      _Chip(
                        palette: palette,
                        icon: Icons.landscape_rounded,
                        text: '${theme.label} theme unlocked',
                      ),
                    for (final award in outcome.newStickers)
                      _Chip(
                        key: ValueKey('summary-sticker-${award.sticker.id}'),
                        palette: palette,
                        leading: SizedBox.square(
                          dimension: 26,
                          child: StickerArt(
                            sticker: award.sticker,
                            sparkle: widget.animateArt,
                          ),
                        ),
                        text: 'New sticker: ${award.sticker.name}',
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.palette,
    required this.caption,
    required this.value,
    this.leading,
  });

  final CampPalette palette;
  final String caption;
  final String value;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PanelCaption(caption, palette: palette),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 15,
            height: 1.1,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: palette.textSecondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Expanded(child: text),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.palette,
    required this.text,
    this.icon,
    this.leading,
    this.strong = false,
  });

  final CampPalette palette;
  final IconData? icon;

  /// Shown instead of [icon] (a sticker badge).
  final Widget? leading;
  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final fg = strong ? palette.onAccent : palette.textPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: strong ? palette.accent : palette.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: strong ? palette.accent : palette.panelBorder,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading ?? Icon(icon, size: 16, color: fg),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: fg,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
