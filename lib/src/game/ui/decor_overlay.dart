import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../art/camp_palette.dart';
import '../../art/sticker_art.dart';
import '../../meta/camp_progress.dart';
import '../../meta/stickers.dart';
import 'camp_ui.dart';

/// Decor screen: a board-shaped frame with the 10 sticker slots and the
/// sticker tray (owned stickers; locked ones as silhouettes with their
/// level). Pick a sticker, then a slot: it sticks there, swapping with a
/// sticker already on it. Tapping a stuck sticker picks it; tapping it
/// again returns it to the tray. Escape or the close button closes it.
class DecorOverlay extends StatefulWidget {
  const DecorOverlay({
    super.key,
    required this.progress,
    required this.onPlace,
    required this.onRemove,
    required this.onClose,
    this.animateArt = true,
  });

  final CampProgress progress;

  /// Sticks a sticker id on a slot (see [CampProgress.withSticker]).
  final void Function(String id, int slot) onPlace;
  final ValueChanged<int> onRemove;
  final VoidCallback onClose;
  final bool animateArt;

  @override
  State<DecorOverlay> createState() => _DecorOverlayState();
}

class _DecorOverlayState extends State<DecorOverlay> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'DecorOverlay');

  /// The first tray sticker (always owned) takes focus on open, so arrows
  /// and Enter work right away.
  final FocusNode _firstSticker = FocusNode(debugLabel: 'DecorFirstSticker');
  String? _selected;

  static final Map<LogicalKeyboardKey, TraversalDirection> _arrows = {
    LogicalKeyboardKey.arrowLeft: TraversalDirection.left,
    LogicalKeyboardKey.arrowRight: TraversalDirection.right,
    LogicalKeyboardKey.arrowUp: TraversalDirection.up,
    LogicalKeyboardKey.arrowDown: TraversalDirection.down,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _firstSticker.requestFocus();
    });
  }

  @override
  void dispose() {
    _firstSticker.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (event is KeyDownEvent) widget.onClose();
      return KeyEventResult.handled;
    }
    final direction = _arrows[key];
    if (direction == null || event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }
    // Arrows move focus between stickers and slots (the web shortcuts
    // would scroll instead).
    final focused = FocusManager.instance.primaryFocus;
    if (focused == null || focused == _focusNode) {
      _focusNode.nextFocus();
    } else {
      focused.focusInDirection(direction);
    }
    return KeyEventResult.handled;
  }

  StickerSlots get _slots => widget.progress.stickerSlots;

  void _tapTray(Sticker sticker) {
    setState(() => _selected = _selected == sticker.id ? null : sticker.id);
  }

  void _tapSlot(int slot) {
    final occupant = _slots.at(slot);
    final selected = _selected;
    if (selected == null) {
      if (occupant != null) setState(() => _selected = occupant);
      return;
    }
    if (selected == occupant) {
      widget.onRemove(slot);
    } else {
      widget.onPlace(selected, slot);
    }
    setState(() => _selected = null);
  }

  String get _hint {
    final selected = _selected == null ? null : Sticker.byId(_selected!);
    if (selected == null) {
      return 'Pick a sticker, then a slot around the board.';
    }
    if (_slots.slotOf(selected.id) != null) {
      return 'Tap a slot to move ${selected.name}, or tap it again '
          'to take it off.';
    }
    return 'Tap a slot to stick ${selected.name}.';
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.progress;
    final palette = CampPalette.of(progress.selectedTheme);
    final owned = progress.ownedStickers.length;
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
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Material(
                    type: MaterialType.transparency,
                    child: CampPanel(
                      palette: palette,
                      radius: 28,
                      padding: const EdgeInsets.fromLTRB(18, 14, 10, 16),
                      // Header and hint stay put; frame and tray scroll.
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.auto_awesome_rounded,
                                  color: palette.textPrimary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Decorate Camp',
                                      style: TextStyle(
                                        color: palette.textPrimary,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                                Text(
                                  '$owned / ${Sticker.count} stickers',
                                  key: const ValueKey('decor-count'),
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
                                  tooltip: 'Close decorate',
                                  onPressed: widget.onClose,
                                  size: 40,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _hint,
                              key: const ValueKey('decor-hint'),
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Flexible(
                              child: SingleChildScrollView(
                                child: LayoutBuilder(
                                  builder: (context, constraints) =>
                                      _body(constraints.maxWidth, palette),
                                ),
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

  /// Frame beside the tray when there is room, above it otherwise.
  Widget _body(double width, CampPalette palette) {
    if (width >= 560) {
      final frame = math.min(320.0, width * 0.48);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _frame(frame, palette),
          const SizedBox(width: 16),
          Expanded(child: _tray(width - frame - 16, palette)),
        ],
      );
    }
    final frame = math.min(340.0, width);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(child: _frame(frame, palette)),
        const SizedBox(height: 14),
        _tray(width, palette),
      ],
    );
  }

  Widget _frame(double size, CampPalette palette) {
    final lane = size * 0.17;
    final board = size - lane * 2;
    final d = StickerSlotGeometry.diameter(lane);
    return SizedBox.square(
      key: const ValueKey('decor-frame'),
      dimension: size,
      child: Stack(
        children: [
          Positioned(
            left: lane,
            top: lane,
            width: board,
            height: board,
            child: _MiniBoard(palette: palette),
          ),
          for (var slot = 0; slot < StickerSlots.count; slot++)
            Positioned.fromRect(
              rect: Rect.fromCenter(
                center:
                    Offset(lane, lane) +
                    StickerSlotGeometry.center(slot, board, lane),
                width: d,
                height: d,
              ),
              child: _SlotButton(
                slot: slot,
                sticker: _slots.at(slot) == null
                    ? null
                    : Sticker.byId(_slots.at(slot)!),
                selected: _selected != null && _slots.at(slot) == _selected,
                armed: _selected != null,
                palette: palette,
                animate: widget.animateArt,
                onTap: () => _tapSlot(slot),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tray(double width, CampPalette palette) {
    const columns = 5;
    const spacing = 8.0;
    final cell = ((width - spacing * (columns - 1)) / columns).clamp(
      40.0,
      78.0,
    );
    final level = widget.progress.level;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelCaption('Sticker tray', palette: palette),
        const SizedBox(height: 8),
        Wrap(
          spacing: spacing,
          runSpacing: 8,
          children: [
            for (final sticker in Sticker.catalog)
              _TrayTile(
                sticker: sticker,
                size: cell,
                owned: sticker.isOwnedAt(level),
                placed: _slots.slotOf(sticker.id) != null,
                selected: _selected == sticker.id,
                palette: palette,
                animate: widget.animateArt,
                focusNode: sticker.level == 1 ? _firstSticker : null,
                onTap: () => _tapTray(sticker),
              ),
          ],
        ),
      ],
    );
  }
}

/// Board-shaped stand-in with the 4x4 plots, so slots read as "around the
/// board".
class _MiniBoard extends StatelessWidget {
  const _MiniBoard({required this.palette});

  final CampPalette palette;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        final pad = side * 0.045;
        final gap = side * 0.015;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(side * 0.08),
            color: palette.groundBoard,
            border: Border.all(
              color: Color.lerp(palette.groundBoard, Colors.black, 0.25)!,
              width: 2,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(pad),
            child: Column(
              children: [
                for (var row = 0; row < 4; row++)
                  Expanded(
                    child: Row(
                      children: [
                        for (var col = 0; col < 4; col++)
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.all(gap),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(
                                    side * 0.04,
                                  ),
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SlotButton extends StatelessWidget {
  const _SlotButton({
    required this.slot,
    required this.sticker,
    required this.selected,
    required this.armed,
    required this.palette,
    required this.animate,
    required this.onTap,
  });

  final int slot;
  final Sticker? sticker;
  final bool selected;

  /// A sticker is picked: empty slots invite a tap.
  final bool armed;
  final CampPalette palette;
  final bool animate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sticker = this.sticker;
    return Semantics(
      button: true,
      selected: selected,
      label: sticker == null
          ? 'Sticker slot ${slot + 1}, empty'
          : 'Sticker slot ${slot + 1}, ${sticker.name}',
      child: Material(
        type: MaterialType.transparency,
        child: InkResponse(
          key: ValueKey('decor-slot-$slot'),
          onTap: onTap,
          customBorder: const CircleBorder(),
          highlightShape: BoxShape.circle,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: sticker == null
                  ? Colors.white.withValues(alpha: armed ? 0.35 : 0.18)
                  : null,
              border: sticker == null || selected
                  ? Border.all(
                      color: selected || armed
                          ? palette.accent
                          : palette.textSecondary.withValues(alpha: 0.5),
                      width: selected ? 3 : 2,
                    )
                  : null,
            ),
            child: sticker == null
                ? Icon(
                    Icons.add_rounded,
                    color: palette.textSecondary.withValues(alpha: 0.7),
                  )
                : Transform.rotate(
                    angle: StickerSlotGeometry.tilt(slot),
                    child: StickerArt(sticker: sticker, sparkle: animate),
                  ),
          ),
        ),
      ),
    );
  }
}

class _TrayTile extends StatelessWidget {
  const _TrayTile({
    required this.sticker,
    required this.size,
    required this.owned,
    required this.placed,
    required this.selected,
    required this.palette,
    required this.animate,
    required this.onTap,
    this.focusNode,
  });

  final Sticker sticker;
  final double size;
  final FocusNode? focusNode;
  final bool owned;
  final bool placed;
  final bool selected;
  final CampPalette palette;
  final bool animate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = owned ? sticker.name : 'Lv ${sticker.level}';
    return Semantics(
      button: owned,
      selected: selected,
      enabled: owned,
      label: owned
          ? '${sticker.name}${placed ? ', on the board' : ''}'
          : '${sticker.name}, unlocks at camp level ${sticker.level}',
      excludeSemantics: true,
      child: Material(
        color: selected
            ? palette.accent.withValues(alpha: 0.28)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: ValueKey('decor-sticker-${sticker.id}'),
          focusNode: focusNode,
          borderRadius: BorderRadius.circular(12),
          onTap: owned ? onTap : null,
          child: SizedBox(
            width: size,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: size * 0.8,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Opacity(
                          opacity: placed && !selected ? 0.55 : 1,
                          child: StickerArt(
                            sticker: sticker,
                            silhouette: !owned,
                            sparkle: owned && animate,
                          ),
                        ),
                        if (placed)
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Icon(
                              Icons.check_circle_rounded,
                              size: math.max(14, size * 0.24),
                              color: palette.accent,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: owned
                          ? palette.textPrimary
                          : palette.textSecondary,
                      fontSize: 10,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
