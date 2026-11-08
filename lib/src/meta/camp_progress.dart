import 'camp_theme.dart';
import 'stickers.dart';

/// Facts about one finished (or restarted) run, fed to [CampProgress.applyRun].
class RunSummary {
  const RunSummary({
    required this.score,
    required this.highestTier,
    required this.bestChain,
    required this.placements,
    this.missionXp = 0,
    this.mergeCount = 0,
  });

  final int score;
  final int highestTier;
  final int bestChain;
  final int placements;
  final int mergeCount;

  /// XP already earned from completed missions during the run.
  final int missionXp;
}

/// Result of applying a run to the saved progress.
class RunOutcome {
  const RunOutcome({
    required this.progress,
    required this.xpGained,
    required this.isNewBest,
    required this.previousBest,
    required this.levelBefore,
    required this.levelAfter,
    required this.newlyUnlockedThemes,
    this.newStickers = const <StickerAward>[],
    int? announcedLevel,
  }) : announcedLevel = announcedLevel ?? levelBefore;

  final CampProgress progress;
  final int xpGained;
  final bool isNewBest;
  final int previousBest;
  final int levelBefore;
  final int levelAfter;
  final List<CampTheme> newlyUnlockedThemes;

  /// Stickers of the levels gained, in level order, with their auto slot.
  final List<StickerAward> newStickers;

  /// Highest level already announced before the run ended: [levelBefore],
  /// or higher when the welcome run levelled up mid-run.
  final int announcedLevel;

  /// The run reached a level that was not announced yet.
  bool get announcesLevelUp => levelAfter > announcedLevel;
}

/// Saved meta progress: best score, camp album, camp XP, chosen theme and
/// where the owned stickers are stuck.
///
/// Tuning (measured with a throwaway greedy/random player on the real
/// controller, 400 seeds per player type; scores before missions):
///   random placement   mean 1078  (p10 468, p50 1020, p90 1728)
///   casual (35% noise) mean 2408  (p10 1260, p50 2208, p90 3876)
///   greedy             mean 3408  (p10 1728, p50 3240, p90 5256)
/// With mission rewards (an axe per mission) players finish 3 to 5 missions
/// per run. XP per run = score / 10 + missionXp + 20 (participation, only for
/// runs with at least [participationMinPlacements] placements and one merge);
/// the following tuning measurements predate that merge requirement. Mean
/// XP per run measured 230 (random), 400 (casual), 510 (greedy), so an average
/// player earns roughly 300. Even a 30 point run moves the bar by about 10%.
/// Level curve: reaching level L+1 costs 230 + 55 * (L - 1) XP. Measured runs
/// to reach Lv3 / Lv6 / Lv10: random 2.8 / 8.0 / 18.0, casual 1.9 / 4.8 / 10.7,
/// greedy 1.6 / 4.0 / 8.5; between random and casual that is ~2 / ~6 / ~14.
class CampProgress {
  const CampProgress({
    required this.bestScore,
    required this.discoveredTiers,
    required this.totalXp,
    required this.selectedTheme,
    this.activeRun,
    this.stickerSlots = const StickerSlots.empty(),
    this.stickersSeen,
    this.welcomeRun = false,
  });

  const CampProgress.initial()
    : bestScore = 0,
      discoveredTiers = const <int>{1},
      totalXp = 0,
      activeRun = null,
      stickerSlots = const StickerSlots.empty(),
      stickersSeen = null,
      welcomeRun = false,
      selectedTheme = CampTheme.summer;

  /// Highest camp tier that has an album entry.
  static const int maxAlbumTier = 8;

  /// XP granted for a run with at least [participationMinPlacements]
  /// placements and one merge.
  static const int participationXp = 20;

  /// Placements a run needs before it earns [participationXp].
  static const int participationMinPlacements = 5;

  /// One-time XP for a brand-new player's first merge
  /// (feature-first-minute-rewards). With the first starter missions it
  /// reaches [welcomeLevel] during the first run.
  static const int welcomeBonusXp = 150;

  /// The only level that can be reached mid-run, in the welcome run.
  static const int welcomeLevel = 2;

  final int bestScore;
  final Set<int> discoveredTiers;
  final int totalXp;
  final CampTheme selectedTheme;

  /// Optional live run envelope, validated by the screen before restoration.
  final Map<String, dynamic>? activeRun;

  /// Stickers stuck around the board; only owned stickers, see [withSticker].
  final StickerSlots stickerSlots;

  /// Highest level whose stickers the player was already told about; null
  /// in saves from before stickers existed.
  final int? stickersSeen;

  /// Set from the welcome bonus until that player's first run is settled;
  /// while set the run can level up to [welcomeLevel] mid-run.
  final bool welcomeRun;

  CampProgress withActiveRun(Map<String, dynamic>? run) => CampProgress(
    bestScore: bestScore,
    discoveredTiers: Set.unmodifiable(discoveredTiers),
    totalXp: totalXp,
    selectedTheme: selectedTheme,
    activeRun: run == null ? null : Map.unmodifiable(run),
    stickerSlots: stickerSlots,
    stickersSeen: stickersSeen,
    welcomeRun: welcomeRun,
  );

  /// XP needed to go from [level] to the next one.
  static int xpToAdvance(int level) => 230 + 55 * (level < 1 ? 0 : level - 1);

  /// Total XP at which [level] is reached (0 for level 1).
  static int totalXpForLevel(int level) {
    var total = 0;
    for (var l = 1; l < level; l++) {
      total += xpToAdvance(l);
    }
    return total;
  }

  /// XP awarded for a run's score.
  static int xpForScore(int score) => score <= 0 ? 0 : score ~/ 10;

  /// XP a run earns when it is settled (also used for the live XP of the
  /// welcome run): score XP, mission XP and participation.
  static int runXp(RunSummary summary) {
    if (summary.placements <= 0) return 0;
    return xpForScore(summary.score) +
        (summary.missionXp < 0 ? 0 : summary.missionXp) +
        (summary.placements >= participationMinPlacements &&
                summary.mergeCount > 0
            ? participationXp
            : 0);
  }

  /// Level reached with [xp] total XP.
  static int levelForXp(int xp) => CampProgress(
    bestScore: 0,
    discoveredTiers: const <int>{1},
    totalXp: xp,
    selectedTheme: CampTheme.summer,
  ).level;

  int get level => _split().$1;
  int get xpIntoLevel => _split().$2;
  int get xpForNextLevel => xpToAdvance(level);

  (int, int) _split() {
    var level = 1;
    var left = totalXp < 0 ? 0 : totalXp;
    while (left >= xpToAdvance(level)) {
      left -= xpToAdvance(level);
      level += 1;
    }
    return (level, left);
  }

  bool isThemeUnlocked(CampTheme theme) => level >= theme.requiredLevel;

  /// Level whose stickers are owned: [level], or [welcomeLevel] once the
  /// welcome run levelled up mid-run (its XP is only saved at run end).
  int get stickerLevel {
    final seen = (stickersSeen ?? 0).clamp(0, welcomeLevel);
    return level > seen ? level : seen;
  }

  List<Sticker> get ownedStickers => Sticker.ownedAt(stickerLevel);

  /// Owned stickers not stuck on a slot.
  List<Sticker> get stickerTray => stickerSlots.trayAt(stickerLevel);

  /// Nothing earned yet and no welcome bonus: the next first merge gets
  /// [welcomeBonusXp].
  bool get welcomeBonusDue => totalXp == 0 && bestScore == 0 && !welcomeRun;

  /// Grants the one-time welcome bonus and starts the welcome run.
  CampProgress withWelcomeBonus() {
    if (!welcomeBonusDue) return this;
    return _copy(totalXp: totalXp + welcomeBonusXp, welcomeRun: true);
  }

  /// Display copy with [runXp] not yet saved XP added (HUD in the welcome
  /// run); never saved.
  CampProgress withPendingXp(int runXp) =>
      runXp <= 0 ? this : _copy(totalXp: totalXp + runXp);

  /// Mid-run level-up of the welcome run: with [runXp] earned so far, the
  /// levels up to [welcomeLevel] that were not announced get their sticker
  /// stuck on the first empty slot, and [stickersSeen] moves up so the run's
  /// end neither repeats nor double counts them. Returns this progress when
  /// nothing is due; [awards] lists what was given.
  CampProgress withLiveLevelUp(int runXp, {List<StickerAward>? awards}) {
    if (!welcomeRun) return this;
    final live = levelForXp(totalXp + (runXp < 0 ? 0 : runXp));
    final target = live < welcomeLevel ? live : welcomeLevel;
    final from = stickerLevel;
    if (target <= from) return this;
    var slots = stickerSlots;
    for (var l = from + 1; l <= target; l++) {
      final sticker = Sticker.forLevel(l);
      if (sticker == null) break;
      final slot = slots.firstEmpty;
      if (slot != null) slots = slots.put(sticker.id, slot);
      awards?.add(StickerAward(sticker, slot));
    }
    return _copy(stickerSlots: slots, stickersSeen: target);
  }

  /// No saved sticker marker and nothing earned yet: a first-ever load.
  bool get _isNewPlayer =>
      stickersSeen == null && totalXp == 0 && bestScore == 0;

  /// Owned stickers the player has not been told about yet: those above
  /// [stickersSeen]. A brand-new player is told nothing; their first
  /// sticker is stuck on the board instead (see [withStickersSeen]).
  int get unseenStickerCount {
    if (_isNewPlayer) return 0;
    final owned = Sticker.ownedCount(level);
    return (owned - Sticker.ownedCount(stickersSeen ?? 0)).clamp(0, owned);
  }

  /// Marks every owned sticker as announced. A brand-new player also gets
  /// their owned stickers (the Lv1 Pennant) stuck on the first empty slots,
  /// so the board shows one from the first run; returning players find
  /// theirs in the tray. Never lowers a marker above the current level.
  CampProgress withStickersSeen() {
    final seen = stickersSeen;
    if (seen != null && seen >= level) return this;
    var slots = stickerSlots;
    if (_isNewPlayer) {
      for (final sticker in stickerTray) {
        final slot = slots.firstEmpty;
        if (slot == null) break;
        slots = slots.put(sticker.id, slot);
      }
    }
    return _copy(stickerSlots: slots, stickersSeen: level);
  }

  /// Sticks owned sticker [id] on [slot] (swapping, see [StickerSlots.put]).
  CampProgress withSticker(String id, int slot) {
    if (!(Sticker.byId(id)?.isOwnedAt(stickerLevel) ?? false)) return this;
    final next = stickerSlots.put(id, slot);
    return identical(next, stickerSlots) ? this : _copy(stickerSlots: next);
  }

  /// Returns the sticker on [slot] to the tray.
  CampProgress withoutSticker(int slot) {
    final next = stickerSlots.remove(slot);
    return identical(next, stickerSlots) ? this : _copy(stickerSlots: next);
  }

  CampProgress withDiscovered(int tier) {
    final clamped = tier.clamp(1, maxAlbumTier);
    if (discoveredTiers.contains(clamped)) return this;
    return _copy(discoveredTiers: {...discoveredTiers, clamped});
  }

  /// Returns this progress unchanged when [theme] is still locked.
  CampProgress withTheme(CampTheme theme) {
    if (!isThemeUnlocked(theme)) return this;
    return _copy(selectedTheme: theme);
  }

  RunOutcome applyRun(RunSummary summary) {
    final levelBefore = level;
    // Only the welcome run's mid-run level-up counts as announced early; a
    // stickersSeen above the level from elsewhere keeps the old behaviour.
    final announced = stickerLevel;
    if (summary.placements <= 0) {
      return RunOutcome(
        progress: withActiveRun(null)._copy(welcomeRun: false),
        xpGained: 0,
        isNewBest: false,
        previousBest: bestScore,
        levelBefore: levelBefore,
        levelAfter: levelBefore,
        newlyUnlockedThemes: const <CampTheme>[],
      );
    }
    final xp = runXp(summary);
    final isNewBest = summary.score > bestScore;
    var next = withActiveRun(null)._copy(
      bestScore: isNewBest ? summary.score : bestScore,
      totalXp: totalXp + xp,
      welcomeRun: false,
    );
    // The screen records every camp the moment it is built; the run only
    // guarantees its highest camp is in the album.
    next = next.withDiscovered(summary.highestTier);
    final levelAfter = next.level;
    // Each level gained awards its sticker, stuck on the first empty slot
    // in level order (or left in the tray when the slots are full). Levels
    // already announced mid-run (welcome run) are skipped.
    final awards = <StickerAward>[];
    var slots = next.stickerSlots;
    for (var l = announced + 1; l <= levelAfter; l++) {
      final sticker = Sticker.forLevel(l);
      if (sticker == null) break;
      final slot = slots.firstEmpty;
      if (slot != null) slots = slots.put(sticker.id, slot);
      awards.add(StickerAward(sticker, slot));
    }
    if (levelAfter > announced) {
      next = next._copy(
        stickerSlots: slots,
        stickersSeen: levelAfter > (stickersSeen ?? 0)
            ? levelAfter
            : stickersSeen,
      );
    }
    return RunOutcome(
      progress: next,
      xpGained: xp,
      isNewBest: isNewBest,
      previousBest: bestScore,
      levelBefore: levelBefore,
      levelAfter: levelAfter,
      newlyUnlockedThemes: [
        for (final theme in CampTheme.values)
          if (announced < theme.requiredLevel &&
              levelAfter >= theme.requiredLevel)
            theme,
      ],
      newStickers: awards,
      announcedLevel: announced,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'bestScore': bestScore,
    'discoveredTiers': (discoveredTiers.toList()..sort()),
    'totalXp': totalXp,
    'selectedTheme': selectedTheme.name,
    if (activeRun != null) 'activeRun': activeRun,
    'stickerSlots': stickerSlots.toJson(),
    'stickerSlotsVersion': StickerSlots.layoutVersion,
    if (stickersSeen != null) 'stickersSeen': stickersSeen,
    if (welcomeRun) 'welcomeRun': true,
  };

  /// Tolerant parser: any missing or invalid field falls back on its own.
  factory CampProgress.fromJson(Object? json) {
    if (json is! Map) return const CampProgress.initial();
    int readInt(Object? value) =>
        value is num && value.isFinite && value >= 0 && value <= 1000000000
        ? value.toInt()
        : 0;
    final tiers = <int>{1};
    final rawTiers = json['discoveredTiers'];
    if (rawTiers is List) {
      for (final value in rawTiers) {
        if (value is num && value.isFinite) {
          tiers.add(value.toInt().clamp(1, maxAlbumTier));
        }
      }
    }
    var progress = CampProgress(
      bestScore: readInt(json['bestScore']),
      discoveredTiers: Set.unmodifiable(tiers),
      totalXp: readInt(json['totalXp']),
      selectedTheme: CampTheme.summer,
      activeRun:
          json['activeRun'] is Map &&
              (json['activeRun'] as Map).keys.every((key) => key is String)
          ? Map<String, dynamic>.unmodifiable(json['activeRun'] as Map)
          : null,
    );
    final theme = CampTheme.fromName(
      json['selectedTheme'] is String ? json['selectedTheme'] as String : null,
    );
    progress = progress.withTheme(theme);
    final seen = json['stickersSeen'];
    progress = progress._copy(
      stickersSeen: seen is num && seen.isFinite && seen >= 0 && seen <= 1000
          ? seen.toInt()
          : null,
      welcomeRun: json['welcomeRun'] == true,
    );
    // Saves without a slot layout version use the ten-slot layout; any
    // other version is read as the current one.
    final layout = json['stickerSlotsVersion'];
    return progress._copy(
      stickerSlots: StickerSlots.fromJson(
        json['stickerSlots'],
        level: progress.stickerLevel,
        legacy: layout == null || layout == 1,
      ),
    );
  }

  CampProgress _copy({
    int? bestScore,
    Set<int>? discoveredTiers,
    int? totalXp,
    CampTheme? selectedTheme,
    StickerSlots? stickerSlots,
    int? stickersSeen,
    bool? welcomeRun,
  }) {
    return CampProgress(
      bestScore: bestScore ?? this.bestScore,
      discoveredTiers: Set.unmodifiable(
        discoveredTiers ?? this.discoveredTiers,
      ),
      totalXp: totalXp ?? this.totalXp,
      selectedTheme: selectedTheme ?? this.selectedTheme,
      activeRun: activeRun,
      stickerSlots: stickerSlots ?? this.stickerSlots,
      stickersSeen: stickersSeen ?? this.stickersSeen,
      welcomeRun: welcomeRun ?? this.welcomeRun,
    );
  }
}
