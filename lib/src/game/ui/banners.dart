import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../art/camp_palette.dart';
import '../../art/camp_tile_art.dart';
import '../../meta/camp_theme.dart';
import '../merge_camp_controller.dart';

/// Plays a one-shot [duration] animation once and then calls [onDone].
/// Uses the ticker (not a Timer), so nothing is left pending in tests.
abstract class _OneShotState<T extends StatefulWidget> extends State<T>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  Duration get duration;
  VoidCallback? get onDone;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(vsync: this, duration: duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) onDone?.call();
      })
      ..forward();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  /// 0..1 entry, 1 while holding, 1..0 on exit.
  double presence({double enter = 0.15, double exit = 0.2}) {
    final t = controller.value;
    if (t < enter) return Curves.easeOutBack.transform(t / enter);
    if (t > 1 - exit) return Curves.easeIn.transform((1 - t) / exit);
    return 1;
  }
}

/// Centered "Chain xN!" over the board.
class ChainBanner extends StatefulWidget {
  const ChainBanner({
    super.key,
    required this.chain,
    required this.palette,
    this.onDone,
  });

  final int chain;
  final CampPalette palette;
  final VoidCallback? onDone;

  @override
  State<ChainBanner> createState() => _ChainBannerState();
}

class _ChainBannerState extends _OneShotState<ChainBanner> {
  @override
  Duration get duration => const Duration(milliseconds: 1300);

  @override
  VoidCallback? get onDone => widget.onDone;

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return IgnorePointer(
      child: Center(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            final p = presence();
            return Opacity(
              opacity: p.clamp(0.0, 1.0),
              child: Transform.rotate(
                angle: -0.06,
                child: Transform.scale(scale: 0.5 + 0.5 * p, child: child),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(palette.accent, Colors.white, 0.35)!,
                  palette.accent,
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Text(
              'Chain x${widget.chain}!',
              style: TextStyle(
                color: palette.onAccent,
                fontSize: 34 + math.min(4, widget.chain) * 2,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Non-blocking "New camp discovered!" card with the camp art and name.
class DiscoveryBanner extends StatefulWidget {
  const DiscoveryBanner({
    super.key,
    required this.tier,
    required this.theme,
    this.animateArt = true,
    this.onDone,
  });

  final int tier;
  final CampTheme theme;
  final bool animateArt;
  final VoidCallback? onDone;

  @override
  State<DiscoveryBanner> createState() => _DiscoveryBannerState();
}

class _DiscoveryBannerState extends _OneShotState<DiscoveryBanner> {
  @override
  Duration get duration => const Duration(milliseconds: 2500);

  @override
  VoidCallback? get onDone => widget.onDone;

  @override
  Widget build(BuildContext context) {
    final palette = CampPalette.of(widget.theme);
    return IgnorePointer(
      child: ExcludeFocus(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            final p = presence(enter: 0.1, exit: 0.12);
            return Opacity(
              opacity: p.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, -24 * (1 - p)),
                child: child,
              ),
            );
          },
          child: Container(
            key: const ValueKey('discovery-banner'),
            padding: const EdgeInsets.fromLTRB(10, 10, 20, 10),
            decoration: BoxDecoration(
              color: palette.panel,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: palette.accent, width: 2.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 56,
                  child: CampTileArt(
                    tier: widget.tier,
                    theme: widget.theme,
                    animate: widget.animateArt,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'New camp discovered!',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          MergeCampController.campTierName(widget.tier),
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ToastMessage {
  const ToastMessage({
    required this.id,
    required this.text,
    required this.icon,
  });

  final int id;
  final String text;
  final IconData icon;
}

/// Short notice ("Mission complete: ...") that slides in and out.
class CampToast extends StatefulWidget {
  const CampToast({
    super.key,
    required this.message,
    required this.palette,
    this.onDone,
  });

  final ToastMessage message;
  final CampPalette palette;
  final VoidCallback? onDone;

  @override
  State<CampToast> createState() => _CampToastState();
}

class _CampToastState extends _OneShotState<CampToast> {
  @override
  Duration get duration => const Duration(milliseconds: 2600);

  @override
  VoidCallback? get onDone => widget.onDone;

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final p = presence(enter: 0.1, exit: 0.12);
          return Opacity(
            opacity: p.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, 12 * (1 - p)),
              child: child,
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFF2F6B45),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF8BE08F), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x44000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.message.icon, color: palette.accent, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.message.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
