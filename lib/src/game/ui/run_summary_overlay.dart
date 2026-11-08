import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../art/camp_palette.dart';
import '../../art/camp_tile_art.dart';
import '../../art/sticker_art.dart';
import '../../meta/camp_progress.dart';
import '../../meta/camp_theme.dart';
import '../../meta/next_goal.dart';
import '../merge_camp_controller.dart';
import '../share/result_card.dart';
import '../share/result_share.dart';
import 'banners.dart';
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

/// Renders the shared card; tests inject a fake.
typedef ResultCardRenderer = Future<Uint8List?> Function(ResultCardData data);

/// "Camp jammed!" summary with score count-up, best, stats, the XP bar, the
/// next goals and the share actions (feature-next-goal-share). The board
/// underneath gets no input while this is open.
class RunSummaryOverlay extends StatefulWidget {
  const RunSummaryOverlay({
    super.key,
    required this.report,
    required this.theme,
    required this.progress,
    required this.onPlayAgain,
    required this.onAlbum,
    required this.onDecorate,
    required this.playAgainFocus,
    this.board = const <int?>[],
    this.shareLink,
    this.share = const ResultShare(),
    this.renderCard = renderResultCard,
    this.busy = false,
    this.animateArt = true,
  });

  final RunReport report;
  final CampTheme theme;

  /// Saved progress after the run (goals, level, stickers on the card).
  final CampProgress progress;

  /// Final board shown on the result card.
  final List<int?> board;

  /// Game page in shared results; null hides the share actions (GamePix).
  final String? shareLink;
  final ResultShare share;
  final ResultCardRenderer renderCard;
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

  Future<Uint8List?>? _card;
  bool _compact = false;
  bool _sharing = false;
  int _toastSerial = 0;
  ToastMessage? _toast;

  @override
  void initState() {
    super.initState();
    // The board's Focus holds primary focus, so autofocus alone would not
    // move it to the button.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.playAgainFocus.requestFocus();
    });
    // Web Share needs the user's tap to be recent, so the card is rendered
    // ahead of time once the entrance animation is over (not on the tap).
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted && _canShare) {
        unawaited(_cardBytes());
      }
    });
  }

  bool get _canShare => widget.shareLink != null && widget.share.canShare;

  @override
  void didUpdateWidget(RunSummaryOverlay old) {
    super.didUpdateWidget(old);
    // Decorate and Album open over the summary and may change the card.
    if (old.theme != widget.theme ||
        old.progress.stickerSlots != widget.progress.stickerSlots ||
        old.progress.level != widget.progress.level ||
        old.report.score != widget.report.score ||
        old.report.highestTier != widget.report.highestTier ||
        old.report.outcome != widget.report.outcome ||
        !listEquals(old.board, widget.board)) {
      _card = null;
      // Render the new card ahead of the next Share tap as well.
      if (_canShare && _controller.isCompleted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _canShare) unawaited(_cardBytes());
        });
      }
    }
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
    // Landscape screens up to laptop height (16:9 portal frames, phones
    // turned sideways) put the buttons beside the facts so nothing scrolls
    // out of sight.
    final screen = MediaQuery.sizeOf(context);
    final wide =
        screen.width >= 640 &&
        screen.width > screen.height &&
        screen.height < 800;
    // Short screens trim the decoration so the facts keep some room next
    // to the pinned goal and buttons.
    _compact = screen.height < (wide ? 520 : 720);
    final facts = SingleChildScrollView(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => _content(context, palette, report, outcome),
      ),
    );
    return Stack(
      children: [
        const ModalBarrier(dismissible: false, color: Color(0x99101A14)),
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: wide ? 760 : 440),
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
                      padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
                      child: wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(child: facts),
                                const SizedBox(width: 18),
                                SizedBox(
                                  width: 260,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: _actions(palette),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Flexible(child: facts),
                                const SizedBox(height: 12),
                                ..._actions(palette),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_toast != null)
          Positioned(
            left: 16,
            right: 16,
            top: 8,
            child: SafeArea(
              child: Center(
                child: CampToast(
                  key: ValueKey('summary-toast-${_toast!.id}'),
                  message: _toast!,
                  palette: palette,
                  onDone: () {
                    if (mounted) setState(() => _toast = null);
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Play again (the biggest button, always visible below the scrolling
  /// facts), then the small secondary and share buttons.
  List<Widget> _actions(CampPalette palette) {
    final link = widget.shareLink;
    final share = widget.share;
    final canSave = link != null && share.canSaveImage;
    final canShare = _canShare;
    Widget small(String label, IconData icon, VoidCallback? onPressed) =>
        Expanded(
          child: CampButton(
            palette: palette,
            label: label,
            icon: icon,
            primary: false,
            height: 42,
            fontSize: 13,
            onPressed: onPressed,
          ),
        );
    List<Widget> spaced(List<Widget> children) => [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        children[i],
      ],
    ];
    final busy = _sharing;
    return [
      _goalHighlight(palette),
      const SizedBox(height: 10),
      CampButton(
        key: const ValueKey('summary-play-again'),
        palette: palette,
        label: 'Play again',
        icon: Icons.replay_rounded,
        height: _compact ? 54 : 60,
        fontSize: _compact ? 19 : 21,
        focusNode: widget.playAgainFocus,
        onPressed: widget.busy ? null : widget.onPlayAgain,
      ),
      const SizedBox(height: 8),
      Row(
        children: spaced([
          small('Album', Icons.collections_bookmark_rounded, widget.onAlbum),
          small('Decorate', Icons.auto_awesome_rounded, widget.onDecorate),
        ]),
      ),
      if (link != null) ...[
        const SizedBox(height: 8),
        Row(
          key: const ValueKey('summary-share-row'),
          children: spaced([
            small(
              'Copy result',
              Icons.content_copy_rounded,
              busy ? null : () => unawaited(_copy(link)),
            ),
            if (canSave)
              small(
                'Save card',
                Icons.download_rounded,
                busy ? null : () => unawaited(_saveCard()),
              ),
            if (canShare)
              small(
                'Share',
                Icons.ios_share_rounded,
                busy ? null : () => unawaited(_shareResult(link)),
              ),
          ]),
        ),
      ],
      if (!_compact) ...[
        const SizedBox(height: 4),
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
    ];
  }

  String _shareText(String link) => resultShareText(
    score: widget.report.score,
    highestTier: widget.report.highestTier,
    level: widget.progress.level,
    link: link,
  );

  ResultCardData get _cardData {
    final outcome = widget.report.outcome;
    return ResultCardData(
      score: widget.report.score,
      best: outcome == null
          ? math.max(widget.progress.bestScore, widget.report.score)
          : math.max(outcome.previousBest, widget.report.score),
      isNewBest: outcome?.isNewBest ?? false,
      highestTier: widget.report.highestTier,
      level: widget.progress.level,
      board: widget.board,
      stickerSlots: widget.progress.stickerSlots,
      theme: widget.theme,
    );
  }

  /// The card is rendered once per summary (again only when its inputs
  /// change); a failed render is retried on the next request.
  Future<Uint8List?> _cardBytes() {
    final pending = _card;
    if (pending != null) return pending;
    final completer = Completer<Uint8List?>();
    _card = completer.future;
    () async {
      Uint8List? png;
      try {
        png = await widget.renderCard(_cardData);
      } catch (_) {}
      if (png == null && identical(_card, completer.future)) _card = null;
      completer.complete(png);
    }();
    return completer.future;
  }

  void _notify(String text, IconData icon) {
    if (!mounted) return;
    setState(() {
      _toastSerial += 1;
      _toast = ToastMessage(id: _toastSerial, text: text, icon: icon);
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      await action();
    } catch (_) {
      _notify('Something went wrong', Icons.error_outline_rounded);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _copy(String link) => _run(() async {
    var ok = false;
    try {
      ok = await widget.share.copyText(_shareText(link));
    } catch (_) {}
    _notify(
      ok ? 'Copied!' : 'Could not copy',
      ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
    );
  });

  Future<void> _saveCard() => _run(() async {
    var ok = false;
    try {
      final png = await _cardBytes();
      if (png != null) {
        ok = await widget.share.saveImage(png, resultCardFileName);
      }
    } catch (_) {}
    _notify(
      ok ? 'Card saved' : 'Could not save',
      ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
    );
  });

  Future<void> _shareResult(String link) => _run(() async {
    var status = ShareStatus.failed;
    try {
      final png = await _cardBytes();
      status = await widget.share.share(
        text: _shareText(link),
        png: png,
        fileName: resultCardFileName,
      );
    } catch (_) {}
    if (status == ShareStatus.failed) {
      _notify('Could not share', Icons.error_outline_rounded);
    }
  });

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
        if (!_compact)
          Text(
            'No empty plots and no Trail Axe left.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        SizedBox(height: _compact ? 6 : 14),
        PanelCaption('Score', palette: palette),
        Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatScore(shownScore),
              key: const ValueKey('summary-score'),
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: _compact ? 42 : 54,
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
        if (nextGoals(widget.progress).length > 1) ...[
          const SizedBox(height: 8),
          PanelCaption('Other goals', palette: palette),
          _moreGoals(palette),
        ],
      ],
    );
  }

  /// The nearest goal with its number, pinned above Play again so it is
  /// always in view (feature-next-goal-share).
  Widget _goalHighlight(CampPalette palette) {
    final goals = nextGoals(widget.progress);
    final top = goals.first;
    final Widget art;
    if (top.sticker != null) {
      art = StickerArt(sticker: top.sticker!, sparkle: widget.animateArt);
    } else if (top.tier != null) {
      art = CampTileArt(
        tier: top.tier!,
        theme: widget.theme,
        animate: false,
        silhouette: true,
      );
    } else {
      art = Icon(
        top.theme != null ? Icons.landscape_rounded : Icons.flag_rounded,
        color: palette.accent,
        size: 34,
      );
    }
    return Column(
      key: const ValueKey('summary-next-goals'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelCaption('Next goal', palette: palette),
        const SizedBox(height: 6),
        Container(
          key: const ValueKey('next-goal-highlight'),
          padding: const EdgeInsets.fromLTRB(10, 8, 12, 10),
          decoration: BoxDecoration(
            color: palette.accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.accent, width: 2),
          ),
          child: Row(
            children: [
              SizedBox.square(dimension: 44, child: Center(child: art)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      top.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      top.detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    CampProgressBar(
                      palette: palette,
                      value: top.progress,
                      height: 8,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The other goals, one line each, at the end of the scrolling facts.
  Widget _moreGoals(CampPalette palette) {
    final goals = nextGoals(widget.progress);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final goal in goals.skip(1))
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4, right: 4),
            child: Row(
              children: [
                Icon(
                  switch (goal.kind) {
                    NextGoalKind.level => Icons.arrow_upward_rounded,
                    NextGoalKind.album => Icons.collections_bookmark_rounded,
                    NextGoalKind.theme => Icons.landscape_rounded,
                  },
                  size: 16,
                  color: palette.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${goal.title} - ${goal.detail}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
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
          if (outcome.announcesLevelUp)
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
