import 'package:flutter/material.dart';

import '../../art/camp_palette.dart';
import '../../art/camp_tile_art.dart';
import '../../meta/camp_progress.dart';
import '../../meta/camp_theme.dart';
import '../../meta/missions.dart';
import '../merge_camp_controller.dart';
import 'camp_ui.dart';

/// Wordmark drawn on the scenery (no panel behind it).
class CampTitle extends StatelessWidget {
  const CampTitle({super.key, this.fontSize = 34});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      'MergeCamp',
      maxLines: 1,
      style: TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.5,
        shadows: const [
          Shadow(color: Color(0xFF3A2414), offset: Offset(0, 3)),
          Shadow(color: Color(0xFF3A2414), offset: Offset(2, 1)),
          Shadow(color: Color(0xFF3A2414), offset: Offset(-2, 1)),
          Shadow(
            color: Color(0x663A2414),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
    );
  }
}

/// Score that bumps briefly whenever it grows.
class ScoreValue extends StatelessWidget {
  const ScoreValue({
    super.key,
    required this.score,
    required this.palette,
    this.fontSize = 34,
  });

  final int score;
  final CampPalette palette;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(score),
      tween: Tween<double>(begin: score == 0 ? 1 : 1.15, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      builder: (context, scale, child) => Transform.scale(
        scale: scale,
        alignment: Alignment.centerLeft,
        child: child,
      ),
      child: Text(
        formatScore(score),
        key: const ValueKey('hud-score'),
        maxLines: 1,
        style: TextStyle(
          color: palette.textPrimary,
          fontSize: fontSize,
          height: 1.05,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// Camp level badge, XP bar and "x / y XP".
class CampLevelCard extends StatelessWidget {
  const CampLevelCard({
    super.key,
    required this.palette,
    required this.progress,
    this.compact = false,
  });

  final CampPalette palette;
  final CampProgress progress;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final into = progress.xpIntoLevel;
    final need = progress.xpForNextLevel;
    return Row(
      children: [
        LevelBadge(
          palette: palette,
          level: progress.level,
          size: compact ? 38 : 50,
        ),
        SizedBox(width: compact ? 8 : 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!compact) PanelCaption('Camp level', palette: palette),
              if (!compact) const SizedBox(height: 6),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(end: need == 0 ? 0 : into / need),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => CampProgressBar(
                  palette: palette,
                  value: value,
                  height: compact ? 8 : 11,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$into / $need XP',
                maxLines: 1,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The next tiles, first one larger.
class NextTiles extends StatelessWidget {
  const NextTiles({
    super.key,
    required this.tiers,
    required this.theme,
    this.size = 64,
    this.animate = true,
  });

  final List<int> tiers;
  final CampTheme theme;
  final double size;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < tiers.length; i++) ...[
          if (i > 0) SizedBox(width: size * 0.12),
          Opacity(
            opacity: i == 0 ? 1 : 0.8,
            child: SizedBox.square(
              dimension: i == 0 ? size : size * 0.68,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutBack,
                  ),
                  child: child,
                ),
                child: CampTileArt(
                  // Keyed by slot and tier so a change animates.
                  key: ValueKey('next-$i-${tiers[i]}'),
                  tier: tiers[i],
                  theme: theme,
                  animate: animate && i == 0,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Trail Axe toggle with charge pips.
class TrailAxeButton extends StatelessWidget {
  const TrailAxeButton({
    super.key,
    required this.palette,
    required this.charges,
    required this.selected,
    required this.onPressed,
    this.compact = false,
  });

  final CampPalette palette;
  final int charges;
  final bool selected;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final bg = selected
        ? palette.accent
        : palette.textSecondary.withValues(alpha: enabled ? 0.14 : 0.07);
    final fg = selected ? palette.onAccent : palette.textPrimary;
    return Tooltip(
      message: 'Trail Axe clears one occupied tile',
      child: Semantics(
        button: true,
        toggled: selected,
        label: 'Trail Axe',
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            key: const ValueKey('trail-axe-button'),
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 10 : 14,
                vertical: compact ? 8 : 12,
              ),
              child: Opacity(
                opacity: enabled || selected ? 1 : 0.55,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.hardware_rounded,
                      color: fg,
                      size: compact ? 24 : 28,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selected ? 'Pick a tile' : 'Trail Axe',
                          style: TextStyle(
                            color: fg,
                            fontSize: compact ? 13 : 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (
                              var i = 0;
                              i < MergeCampController.maxTrailAxes;
                              i++
                            )
                              Container(
                                margin: const EdgeInsets.only(right: 4),
                                width: 14,
                                height: 6,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(3),
                                  color: i < charges
                                      ? (selected
                                            ? palette.onAccent
                                            : palette.accent)
                                      : fg.withValues(alpha: 0.2),
                                ),
                              ),
                            Text(
                              'x$charges',
                              key: const ValueKey('trail-axe-count'),
                              style: TextStyle(
                                color: fg,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
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
    );
  }
}

IconData missionIcon(MissionKind kind) => switch (kind) {
  MissionKind.placeTiles => Icons.add_box_rounded,
  MissionKind.makeChain => Icons.link_rounded,
  MissionKind.buildTier => Icons.cabin_rounded,
  MissionKind.bigMerge => Icons.auto_awesome_rounded,
  MissionKind.reachScore => Icons.star_rounded,
  MissionKind.mergeTimes => Icons.call_merge_rounded,
};

String _progressText(Mission m) {
  if (m.completed) return 'Done';
  switch (m.kind) {
    case MissionKind.makeChain:
    case MissionKind.buildTier:
    case MissionKind.bigMerge:
      // Event goals have no meaningful count to show.
      return '';
    case MissionKind.reachScore:
      return '${formatScore(m.progress)}/${formatScore(m.target)}';
    case MissionKind.placeTiles:
    case MissionKind.mergeTimes:
      return '${m.progress}/${m.target}';
  }
}

/// For event goals (chain, cluster, tier) this shows how close the best
/// attempt got.
double _progressValue(Mission m) {
  if (m.completed) return 1;
  return m.target <= 0 ? 0 : m.progress / m.target;
}

class _MissionCheck extends StatelessWidget {
  const _MissionCheck({
    required this.mission,
    required this.palette,
    required this.size,
  });

  final Mission mission;
  final CampPalette palette;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        child: child,
      ),
      child: mission.completed
          ? Container(
              key: const ValueKey('done'),
              width: size,
              height: size,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF4CAF68),
              ),
              child: Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: size * 0.7,
              ),
            )
          : Container(
              key: const ValueKey('open'),
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.accent.withValues(alpha: 0.22),
              ),
              child: Icon(
                missionIcon(mission.kind),
                color: palette.textPrimary,
                size: size * 0.6,
              ),
            ),
    );
  }
}

/// Wide layout: three mission rows with progress bars.
class MissionsPanel extends StatelessWidget {
  const MissionsPanel({
    super.key,
    required this.palette,
    required this.missions,
    required this.setNumber,
  });

  final CampPalette palette;
  final List<Mission> missions;
  final int setNumber;

  @override
  Widget build(BuildContext context) {
    return CampPanel(
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: PanelCaption('Missions', palette: palette)),
              Text(
                'Set $setNumber',
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SizeTransition(sizeFactor: animation, child: child),
            ),
            child: Column(
              key: ValueKey('mission-set-$setNumber'),
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final m in missions)
                  _MissionRow(mission: m, palette: palette),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Reward: Trail Axe + ${MissionBoard.xpPerMission} XP',
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionRow extends StatelessWidget {
  const _MissionRow({required this.mission, required this.palette});

  final Mission mission;
  final CampPalette palette;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      key: const ValueKey('mission-row'),
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: mission.completed
            ? const Color(0xFF4CAF68).withValues(alpha: 0.16)
            : palette.textSecondary.withValues(alpha: 0.07),
      ),
      child: Row(
        children: [
          _MissionCheck(mission: mission, palette: palette, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        mission.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          decoration: mission.completed
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: palette.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _progressText(mission),
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: _progressValue(mission)),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => CampProgressBar(
                    palette: palette,
                    value: v,
                    height: 6,
                    color: mission.completed ? const Color(0xFF4CAF68) : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Narrow layout: three compact mission chips in a row.
class MissionStrip extends StatelessWidget {
  const MissionStrip({
    super.key,
    required this.palette,
    required this.missions,
    required this.setNumber,
  });

  final CampPalette palette;
  final List<Mission> missions;
  final int setNumber;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: Row(
        key: ValueKey('mission-set-$setNumber'),
        children: [
          for (var i = 0; i < missions.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: _MissionChip(mission: missions[i], palette: palette),
            ),
          ],
        ],
      ),
    );
  }
}

class _MissionChip extends StatelessWidget {
  const _MissionChip({required this.mission, required this.palette});

  final Mission mission;
  final CampPalette palette;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      key: const ValueKey('mission-row'),
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.fromLTRB(7, 7, 7, 7),
      decoration: BoxDecoration(
        color: mission.completed
            ? Color.alphaBlend(const Color(0x334CAF68), palette.panel)
            : palette.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.panelBorder, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2A000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _MissionCheck(mission: mission, palette: palette, size: 20),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  mission.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 11,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          CampProgressBar(
            palette: palette,
            value: _progressValue(mission),
            height: 5,
            color: mission.completed ? const Color(0xFF4CAF68) : null,
          ),
        ],
      ),
    );
  }
}
