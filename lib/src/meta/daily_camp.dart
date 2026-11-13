import 'dart:math' as math;

// Daily Camp rules (feature-daily-camp). Widget-free.

/// Rewarded daily runs needed to refill a used grace.
const int kGraceRefillSolves = 7;

/// Day number of [local]'s calendar date: days since 1970-01-01. Uses the
/// date fields only, so the time zone offset and DST never matter.
int dayIndexOf(DateTime local) => DateTime.utc(
  local.year,
  local.month,
  local.day,
).difference(DateTime.utc(1970)).inDays;

/// Nonzero 31-bit seed for [day]. Only small products are used so the Dart
/// VM and dart2js compute the same value.
int dailySeed(int day) {
  final d = day.clamp(0, 1 << 18);
  final seed = ((d * 7919) ^ 0x0DA11E5) & 0x7FFFFFFF;
  return seed == 0 ? 1 : seed;
}

/// XP a rewarded daily run adds when it brings the streak to [streak].
int dailyBonusXp(int streak) => 40 + 10 * math.min(math.max(streak, 1) - 1, 4);

/// Small deterministic PRNG (xorshift32) that implements [math.Random].
///
/// `Random(seed)` is not guaranteed to give the same sequence on the Dart VM
/// and on the web, and every player must see the same daily pieces. This only
/// uses 32-bit shifts and xors, which behave identically on both.
class SeededRandom implements math.Random {
  SeededRandom(int seed) : _state = _mix(seed);

  static const int _mask = 0xFFFFFFFF;

  int _state;

  static int _mix(int seed) {
    var x = (seed ^ 0x5BD1E995) & _mask;
    if (x == 0) x = 0x9E3779B9;
    for (var i = 0; i < 8; i++) {
      x = _step(x);
    }
    return x;
  }

  static int _step(int x) {
    x ^= (x << 13) & _mask;
    x ^= x >> 17;
    x ^= (x << 5) & _mask;
    return x & _mask;
  }

  int nextUint32() {
    _state = _step(_state);
    return _state;
  }

  @override
  int nextInt(int max) {
    if (max <= 0 || max > _mask) throw RangeError.range(max, 1, _mask, 'max');
    return nextUint32() % max;
  }

  @override
  double nextDouble() => nextUint32() / 4294967296.0;

  @override
  bool nextBool() => (nextUint32() & 1) == 1;
}

/// Persisted daily counters. Immutable; [applyDaily] returns a new value.
class DailyCamp {
  const DailyCamp({
    this.lastDay,
    this.streak = 0,
    this.best = 0,
    this.graceReady = true,
    this.refillLeft = 0,
    this.total = 0,
    this.bestDay,
    this.bestScore = 0,
  });

  /// Last day whose daily run was rewarded, null before the first.
  final int? lastDay;
  final int streak;
  final int best;

  /// Whether a missed day will be forgiven on the next rewarded run.
  final bool graceReady;

  /// Rewarded days still needed to refill the grace (0 when ready).
  final int refillLeft;

  /// Rewarded daily runs ever.
  final int total;

  /// Day of [bestScore], and the best daily score on that day.
  final int? bestDay;
  final int bestScore;

  /// Best score of [today], 0 when none was played yet.
  int bestScoreOn(int today) => bestDay == today ? bestScore : 0;

  /// Whether today's daily run was already rewarded.
  bool rewardedOn(int today) => lastDay != null && lastDay! >= today;

  static const DailyCamp none = DailyCamp();

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (lastDay != null) 'lastDay': lastDay,
    'streak': streak,
    'best': best,
    'graceReady': graceReady,
    'refillLeft': refillLeft,
    'total': total,
    if (bestDay != null) 'bestDay': bestDay,
    'bestScore': bestScore,
  };

  /// Tolerant parser: invalid fields fall back to their defaults.
  factory DailyCamp.fromJson(Object? json) {
    if (json is! Map) return none;
    int? readDay(Object? v) =>
        v is num && v.isFinite && v >= 0 && v <= (1 << 18) ? v.toInt() : null;
    int readCount(Object? v, int max) =>
        v is num && v.isFinite && v >= 0 && v <= max ? v.toInt() : 0;
    final streak = readCount(json['streak'], 100000);
    final lastDay = readDay(json['lastDay']);
    final graceReady = json['graceReady'] != false;
    final refill = readCount(json['refillLeft'], 1000000);
    return DailyCamp(
      lastDay: lastDay,
      streak: lastDay == null ? 0 : streak,
      best: math.max(readCount(json['best'], 100000), streak),
      graceReady: graceReady,
      refillLeft: graceReady
          ? 0
          : (refill >= 1 && refill <= kGraceRefillSolves
                ? refill
                : kGraceRefillSolves),
      total: readCount(json['total'], 1000000),
      bestDay: readDay(json['bestDay']),
      bestScore: readCount(json['bestScore'], 1000000000),
    );
  }
}

/// What one counted daily run changed.
class DailyResult {
  const DailyResult({
    required this.state,
    required this.rewarded,
    required this.bonusXp,
    required this.isDayBest,
    this.graceUsed = false,
  });

  final DailyCamp state;

  /// False when today was already rewarded or the clock is before the last
  /// rewarded day.
  final bool rewarded;
  final int bonusXp;

  /// The run beat the best daily score already saved for [DailyCamp.bestDay].
  final bool isDayBest;
  final bool graceUsed;
}

/// Applies a counted daily run of [day] that scored [score] to [s].
DailyResult applyDaily(DailyCamp s, int day, int score) {
  final sameDayBest = s.bestScoreOn(day);
  final isDayBest = score > sameDayBest;
  final bestDay = isDayBest ? day : (s.bestDay ?? day);
  final bestScore = isDayBest ? score : s.bestScore;

  final last = s.lastDay;
  if (last != null && day <= last) {
    return DailyResult(
      state: DailyCamp(
        lastDay: s.lastDay,
        streak: s.streak,
        best: s.best,
        graceReady: s.graceReady,
        refillLeft: s.refillLeft,
        total: s.total,
        // A past clock must not overwrite a newer day's best score.
        bestDay: day == last ? bestDay : s.bestDay,
        bestScore: day == last ? bestScore : s.bestScore,
      ),
      rewarded: false,
      bonusXp: 0,
      isDayBest: day == last && isDayBest,
    );
  }

  var streak = 1;
  var graceReady = s.graceReady;
  var refill = s.refillLeft;
  var graceUsed = false;
  if (last != null) {
    final gap = day - last;
    if (gap == 1) {
      streak = s.streak + 1;
    } else if (gap == 2 && graceReady) {
      streak = s.streak + 1;
      graceReady = false;
      graceUsed = true;
      refill = kGraceRefillSolves;
    }
  }
  if (!graceUsed && !graceReady) {
    refill = math.max(0, refill - 1);
    if (refill == 0) graceReady = true;
  }
  streak = math.max(1, streak);
  return DailyResult(
    state: DailyCamp(
      lastDay: day,
      streak: streak,
      best: math.max(s.best, streak),
      graceReady: graceReady,
      refillLeft: graceReady ? 0 : refill,
      total: s.total + 1,
      bestDay: day,
      bestScore: isDayBest ? score : sameDayBest,
    ),
    rewarded: true,
    bonusXp: dailyBonusXp(streak),
    isDayBest: isDayBest,
    graceUsed: graceUsed,
  );
}

/// How the streak looks on [today].
enum StreakStatus {
  /// No streak (never played, or broken).
  none,

  /// Today's daily is rewarded.
  safe,

  /// Rewarded yesterday: play today to extend.
  pending,

  /// Missed yesterday, the grace covers it if today is played.
  graceCovers,
}

class StreakView {
  const StreakView(this.current, this.status);
  final int current;
  final StreakStatus status;
}

/// Current streak on [today]. A clock set before the last rewarded day keeps
/// the stored streak instead of breaking it.
StreakView streakOn(DailyCamp s, int today) {
  final last = s.lastDay;
  final streak = math.max(0, s.streak);
  if (last == null || streak == 0) {
    return const StreakView(0, StreakStatus.none);
  }
  final gap = today - last;
  if (gap <= 0) return StreakView(streak, StreakStatus.safe);
  if (gap == 1) return StreakView(streak, StreakStatus.pending);
  if (gap == 2 && s.graceReady) {
    return StreakView(streak, StreakStatus.graceCovers);
  }
  return const StreakView(0, StreakStatus.none);
}

/// Streak a rewarded run on [today] would reach (for the "tomorrow" line and
/// the entry hint), given the saved counters.
int streakIfRewarded(DailyCamp s, int today) {
  final view = streakOn(s, today);
  return view.status == StreakStatus.safe ? view.current : view.current + 1;
}
