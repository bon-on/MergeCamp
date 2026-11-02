import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../art/camp_palette.dart';
import '../../art/camp_tile_art.dart';
import '../../meta/camp_progress.dart';
import '../../meta/camp_theme.dart';
import '../merge_camp_controller.dart';
import 'camp_ui.dart';
import 'hud.dart';

/// Camp album: the 8 camps (undiscovered ones as silhouettes), camp level
/// and the theme picker. Escape or the close button closes it.
class AlbumOverlay extends StatefulWidget {
  const AlbumOverlay({
    super.key,
    required this.progress,
    required this.onSelectTheme,
    required this.onClose,
    this.animateArt = true,
  });

  final CampProgress progress;
  final ValueChanged<CampTheme> onSelectTheme;
  final VoidCallback onClose;
  final bool animateArt;

  @override
  State<AlbumOverlay> createState() => _AlbumOverlayState();
}

class _AlbumOverlayState extends State<AlbumOverlay> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'AlbumOverlay');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (event is KeyDownEvent) widget.onClose();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.progress;
    final theme = progress.selectedTheme;
    final palette = CampPalette.of(theme);
    final found = progress.discoveredTiers.length;
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _onKeyEvent,
      child: Stack(
        children: [
          ModalBarrier(
            dismissible: true,
            color: const Color(0x99101A14),
            onDismiss: widget.onClose,
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Material(
                    type: MaterialType.transparency,
                    child: CampPanel(
                      palette: palette,
                      radius: 28,
                      padding: const EdgeInsets.fromLTRB(20, 14, 12, 18),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(right: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.collections_bookmark_rounded,
                                  color: palette.textPrimary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Camp Album',
                                    style: TextStyle(
                                      color: palette.textPrimary,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                Text(
                                  '$found / ${CampProgress.maxAlbumTier} found',
                                  style: TextStyle(
                                    color: palette.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                PanelIconButton(
                                  palette: palette,
                                  icon: Icons.close_rounded,
                                  tooltip: 'Close album',
                                  onPressed: widget.onClose,
                                  size: 40,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            CampLevelCard(palette: palette, progress: progress),
                            const SizedBox(height: 14),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                const spacing = 10.0;
                                final cell =
                                    ((constraints.maxWidth - spacing * 3) / 4)
                                        .clamp(40.0, 130.0);
                                return Wrap(
                                  spacing: spacing,
                                  runSpacing: 12,
                                  children: [
                                    for (
                                      var tier = 1;
                                      tier <= CampProgress.maxAlbumTier;
                                      tier++
                                    )
                                      _AlbumEntry(
                                        tier: tier,
                                        size: cell,
                                        theme: theme,
                                        palette: palette,
                                        discovered: progress.discoveredTiers
                                            .contains(tier),
                                        animate: widget.animateArt,
                                      ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            PanelCaption('Themes', palette: palette),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final t in CampTheme.values)
                                  _ThemeChip(
                                    theme: t,
                                    palette: palette,
                                    selected: t == theme,
                                    unlocked: progress.isThemeUnlocked(t),
                                    onTap: () => widget.onSelectTheme(t),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Earn camp XP every run to unlock new themes.',
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
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

class _AlbumEntry extends StatelessWidget {
  const _AlbumEntry({
    required this.tier,
    required this.size,
    required this.theme,
    required this.palette,
    required this.discovered,
    required this.animate,
  });

  final int tier;
  final double size;
  final CampTheme theme;
  final CampPalette palette;
  final bool discovered;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: ValueKey('album-tier-$tier'),
      width: size,
      child: Column(
        children: [
          SizedBox.square(
            dimension: size,
            child: CampTileArt(
              tier: tier,
              theme: theme,
              animate: animate && discovered,
              silhouette: !discovered,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            discovered ? MergeCampController.campTierName(tier) : '???',
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              color: discovered ? palette.textPrimary : palette.textSecondary,
              fontSize: 12,
              height: 1.1,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({
    required this.theme,
    required this.palette,
    required this.selected,
    required this.unlocked,
    required this.onTap,
  });

  final CampTheme theme;
  final CampPalette palette;
  final bool selected;
  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final swatch = CampPalette.of(theme);
    final fg = selected ? palette.onAccent : palette.textPrimary;
    return Semantics(
      selected: selected,
      enabled: unlocked,
      child: Material(
        color: selected
            ? palette.accent
            : palette.textSecondary.withValues(alpha: unlocked ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: ValueKey('theme-chip-${theme.name}'),
          borderRadius: BorderRadius.circular(14),
          onTap: unlocked ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 7, 12, 7),
            child: Opacity(
              opacity: unlocked ? 1 : 0.6,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [swatch.skyTop, swatch.hillNear],
                      ),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    theme.label,
                    style: TextStyle(
                      color: fg,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.check_rounded, size: 18, color: fg),
                  ],
                  if (!unlocked) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.lock_rounded, size: 15, color: fg),
                    const SizedBox(width: 2),
                    Text(
                      'Lv ${theme.requiredLevel}',
                      style: TextStyle(
                        color: fg,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
