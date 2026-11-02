import 'package:flutter/material.dart';

import '../../art/camp_palette.dart';

/// Groups digits by thousands: 12345 -> "12,345".
String formatScore(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();
  final buffer = StringBuffer(negative ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Rounded HUD card in the theme's panel color with a soft drop shadow.
class CampPanel extends StatelessWidget {
  const CampPanel({
    super.key,
    required this.palette,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 18,
    this.highlight,
  });

  final CampPalette palette;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Optional outline color (for example while a tool is armed).
  final Color? highlight;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: highlight ?? palette.panelBorder,
          width: highlight == null ? 1.5 : 2.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Small upper-case caption used above panel values.
class PanelCaption extends StatelessWidget {
  const PanelCaption(this.text, {super.key, required this.palette});

  final String text;
  final CampPalette palette;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: palette.textSecondary,
        fontSize: 11,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

/// Rounded progress bar with an accent fill.
class CampProgressBar extends StatelessWidget {
  const CampProgressBar({
    super.key,
    required this.palette,
    required this.value,
    this.height = 10,
    this.color,
  });

  final CampPalette palette;
  final double value;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fill = color ?? palette.accent;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: palette.textSecondary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(height),
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: value.clamp(0.0, 1.0),
        heightFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.lerp(fill, Colors.white, 0.35)!, fill],
            ),
          ),
        ),
      ),
    );
  }
}

/// Round "Lv N" badge.
class LevelBadge extends StatelessWidget {
  const LevelBadge({
    super.key,
    required this.palette,
    required this.level,
    this.size = 44,
  });

  final CampPalette palette;
  final int level;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(palette.accent, Colors.white, 0.3)!,
            palette.accent,
          ],
        ),
        border: Border.all(color: Colors.white, width: size * 0.06),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: EdgeInsets.all(size * 0.12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Lv',
                style: TextStyle(
                  color: palette.onAccent,
                  fontSize: size * 0.22,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '$level',
                style: TextStyle(
                  color: palette.onAccent,
                  fontSize: size * 0.38,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Accent pill button used for the main call to action.
class CampButton extends StatelessWidget {
  const CampButton({
    super.key,
    required this.palette,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = true,
    this.focusNode,
  });

  final CampPalette palette;
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    final text = Text(
      label,
      maxLines: 1,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
    );
    final child = FittedBox(
      fit: BoxFit.scaleDown,
      child: icon == null
          ? text
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [Icon(icon, size: 20), const SizedBox(width: 8), text],
            ),
    );
    if (primary) {
      return FilledButton(
        focusNode: focusNode,
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: palette.onAccent,
          disabledBackgroundColor: palette.accent.withValues(alpha: 0.5),
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: shape,
          elevation: 3,
        ),
        child: child,
      );
    }
    return OutlinedButton(
      focusNode: focusNode,
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.textPrimary,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        side: BorderSide(color: palette.panelBorder, width: 2),
        shape: shape,
      ),
      child: child,
    );
  }
}

/// Square icon button that sits on a panel.
class PanelIconButton extends StatelessWidget {
  const PanelIconButton({
    super.key,
    required this.palette,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 44,
  });

  final CampPalette palette;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      iconSize: size * 0.52,
      constraints: BoxConstraints.tightFor(width: size, height: size),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        foregroundColor: palette.textPrimary,
        backgroundColor: palette.textSecondary.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: Icon(icon),
    );
  }
}
