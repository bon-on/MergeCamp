import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

/// Minimal view of the CrazyGames SDK Data module (localStorage-like API).
abstract class CloudData {
  String? getItem(String key);
  void setItem(String key, String value);
}

/// [SharedPreferencesStorePlatform] that keeps every preference in one JSON
/// item of the CrazyGames Data module, so logged-in players keep their
/// progress across devices. Every write is mirrored to [local] so the
/// browser copy survives if the Data module is later disabled.
class CloudPrefsStore extends SharedPreferencesStorePlatform {
  CloudPrefsStore._(this._cloud, this._local, this._values);

  /// Data module key that holds all preferences.
  static const String cloudKey = 'prefs_v1';

  final CloudData _cloud;
  final SharedPreferencesStorePlatform _local;
  final Map<String, Object> _values;

  /// Loads the cloud snapshot, falling back to the [local] values when the
  /// cloud has none (first run after this feature, or a corrupt value).
  /// Throws if the Data module itself fails, so callers keep [local].
  static Future<CloudPrefsStore> load(
    CloudData cloud,
    SharedPreferencesStorePlatform local,
  ) async {
    final raw = cloud.getItem(cloudKey);
    final values = decode(raw) ?? Map<String, Object>.of(await local.getAll());
    return CloudPrefsStore._(cloud, local, values);
  }

  /// Decodes a stored snapshot; null when missing or malformed.
  @visibleForTesting
  static Map<String, Object>? decode(String? raw) {
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final values = <String, Object>{};
      decoded.forEach((key, value) {
        if (key is! String) return;
        if (value is bool || value is num || value is String) {
          values[key] = value as Object;
        } else if (value is List && value.every((item) => item is String)) {
          values[key] = value.cast<String>().toList();
        }
      });
      return values;
    } on FormatException {
      return null;
    }
  }

  void _flush() {
    try {
      _cloud.setItem(cloudKey, jsonEncode(_values));
    } catch (error) {
      debugPrint('CrazyGames data save failed: $error');
    }
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    _values[key] = value;
    _flush();
    return _local.setValue(valueType, key, value);
  }

  @override
  Future<bool> remove(String key) async {
    _values.remove(key);
    _flush();
    return _local.remove(key);
  }

  @override
  Future<bool> clear() async {
    _values.clear();
    _flush();
    return _local.clear();
  }

  @override
  Future<bool> clearWithPrefix(String prefix) => clearWithParameters(
    ClearParameters(filter: PreferencesFilter(prefix: prefix)),
  );

  @override
  Future<bool> clearWithParameters(ClearParameters parameters) async {
    final filter = parameters.filter;
    _values.removeWhere((key, _) => _matches(key, filter));
    _flush();
    return _local.clearWithParameters(parameters);
  }

  @override
  Future<Map<String, Object>> getAll() async => Map<String, Object>.of(_values);

  @override
  Future<Map<String, Object>> getAllWithPrefix(String prefix) =>
      getAllWithParameters(
        GetAllParameters(filter: PreferencesFilter(prefix: prefix)),
      );

  @override
  Future<Map<String, Object>> getAllWithParameters(
    GetAllParameters parameters,
  ) async {
    final filter = parameters.filter;
    return <String, Object>{
      for (final entry in _values.entries)
        if (_matches(entry.key, filter)) entry.key: entry.value,
    };
  }

  static bool _matches(String key, PreferencesFilter filter) =>
      key.startsWith(filter.prefix) &&
      (filter.allowList == null || filter.allowList!.contains(key));
}
