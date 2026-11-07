/// Camp stickers: level-up rewards stuck around the board (cosmetic only).
///
/// Reaching camp level L (1 <= L <= [Sticker.count]) owns the L-th sticker
/// of [Sticker.catalog]; ownership is derived from the level and never
/// stored. Only where owned stickers are stuck is saved ([StickerSlots]).
class Sticker {
  const Sticker(this.id, this.name, this.level, {this.rare = false});

  final String id;
  final String name;

  /// Camp level that awards this sticker (its 1-based catalog position).
  final int level;

  /// Rare stickers get a gold border and a sparkle in the decor screen.
  final bool rare;

  static const List<Sticker> catalog = [
    Sticker('pennant', 'Pennant', 1),
    Sticker('pine-tree', 'Pine Tree', 2),
    Sticker('acorn', 'Acorn', 3),
    Sticker('lantern', 'Lantern', 4),
    Sticker('spark', 'Spark', 5, rare: true),
    Sticker('marshmallow', 'Marshmallow', 6),
    Sticker('compass', 'Compass', 7),
    Sticker('mug', 'Mug', 8),
    Sticker('hiking-boot', 'Hiking Boot', 9),
    Sticker('moon', 'Moon', 10, rare: true),
    Sticker('binoculars', 'Binoculars', 11),
    Sticker('kite', 'Kite', 12),
    Sticker('mushroom', 'Mushroom', 13),
    Sticker('fox', 'Fox', 14),
    Sticker('owl', 'Owl', 15, rare: true),
    Sticker('map', 'Map', 16),
    Sticker('canoe', 'Canoe', 17),
    Sticker('fish', 'Fish', 18),
    Sticker('butterfly', 'Butterfly', 19),
    Sticker('rainbow', 'Rainbow', 20, rare: true),
    Sticker('bear-cub', 'Bear Cub', 21),
    Sticker('snowflake', 'Snowflake', 22),
    Sticker('leaf', 'Leaf', 23),
    Sticker('sunflower', 'Sunflower', 24),
    Sticker('star-badge', 'Star Badge', 25, rare: true),
  ];

  static int get count => catalog.length;

  static final Map<String, Sticker> _byId = {
    for (final sticker in catalog) sticker.id: sticker,
  };

  static Sticker? byId(String id) => _byId[id];

  /// Sticker awarded for reaching [level]; null past the catalog.
  static Sticker? forLevel(int level) =>
      level >= 1 && level <= catalog.length ? catalog[level - 1] : null;

  /// Number of stickers a player at [level] owns.
  static int ownedCount(int level) => level.clamp(0, catalog.length);

  static List<Sticker> ownedAt(int level) =>
      catalog.sublist(0, ownedCount(level));

  bool isOwnedAt(int level) => this.level <= level;

  @override
  String toString() => 'Sticker($id)';
}

/// A sticker earned by a level-up and where it was auto-placed (null when
/// every slot was taken and it went to the tray).
class StickerAward {
  const StickerAward(this.sticker, this.slot);

  final Sticker sticker;
  final int? slot;
}

/// Which sticker is stuck on each of the [count] fixed slots around the
/// board. Slots 0-2 are above the board, 3-5 below, 6-7 left, 8-9 right.
/// A sticker is on at most one slot and a slot holds at most one sticker.
class StickerSlots {
  const StickerSlots.empty() : _slots = const <int, String>{};

  const StickerSlots._(this._slots);

  static const int count = 10;

  /// Slots drawn next to the board even on narrow portrait screens.
  static const int topBottomCount = 6;

  final Map<int, String> _slots;

  bool get isEmpty => _slots.isEmpty;
  int get length => _slots.length;

  /// Occupied slots in slot order.
  Iterable<int> get occupied => (_slots.keys.toList()..sort());

  String? at(int slot) => _slots[slot];

  int? slotOf(String id) {
    for (final entry in _slots.entries) {
      if (entry.value == id) return entry.key;
    }
    return null;
  }

  int? get firstEmpty {
    for (var slot = 0; slot < count; slot++) {
      if (!_slots.containsKey(slot)) return slot;
    }
    return null;
  }

  /// Stable text form of the placement, used as a cache key.
  String get signature =>
      [for (final slot in occupied) '$slot=${_slots[slot]}'].join(',');

  /// Owned stickers that are not on a slot, in catalog order.
  List<Sticker> trayAt(int level) => [
    for (final sticker in Sticker.ownedAt(level))
      if (slotOf(sticker.id) == null) sticker,
  ];

  /// Sticks [id] on [slot]. A sticker already there swaps into the slot
  /// [id] came from, or goes back to the tray when [id] came from the tray.
  /// Unknown stickers, bad slots and putting a sticker on its own slot
  /// change nothing.
  StickerSlots put(String id, int slot) {
    if (Sticker.byId(id) == null || slot < 0 || slot >= count) return this;
    final from = slotOf(id);
    if (from == slot) return this;
    final occupant = _slots[slot];
    final next = Map<int, String>.of(_slots);
    if (from != null) next.remove(from);
    next[slot] = id;
    if (from != null && occupant != null) next[from] = occupant;
    return StickerSlots._(Map.unmodifiable(next));
  }

  /// Returns the sticker on [slot] to the tray.
  StickerSlots remove(int slot) {
    if (!_slots.containsKey(slot)) return this;
    return StickerSlots._(Map.unmodifiable(Map.of(_slots)..remove(slot)));
  }

  Map<String, String> toJson() => {
    for (final slot in occupied) '$slot': _slots[slot]!,
  };

  /// Tolerant parser: keeps every valid entry and drops stickers not owned
  /// at [level], slots out of range and repeats of a sticker (the lowest
  /// slot wins). Anything that is not a map is an empty placement.
  factory StickerSlots.fromJson(Object? json, {required int level}) {
    if (json is! Map) return const StickerSlots.empty();
    final entries = <int, String>{};
    for (final entry in json.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is! String || value is! String) continue;
      if (key.isEmpty || key.length > 2) continue;
      final slot = int.tryParse(key);
      if (slot == null || slot < 0 || slot >= count || '$slot' != key) {
        continue;
      }
      if (!(Sticker.byId(value)?.isOwnedAt(level) ?? false)) continue;
      entries[slot] = value;
    }
    final kept = <int, String>{};
    final seen = <String>{};
    for (final slot in entries.keys.toList()..sort()) {
      if (seen.add(entries[slot]!)) kept[slot] = entries[slot]!;
    }
    return kept.isEmpty
        ? const StickerSlots.empty()
        : StickerSlots._(Map.unmodifiable(kept));
  }

  @override
  bool operator ==(Object other) =>
      other is StickerSlots && other.signature == signature;

  @override
  int get hashCode => signature.hashCode;
}
