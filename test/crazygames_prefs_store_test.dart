import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_camp/src/platform/crazygames_prefs_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _FakeCloud implements CloudData {
  _FakeCloud([this.items = const <String, String>{}]);

  Map<String, String> items;
  bool failReads = false;

  @override
  String? getItem(String key) {
    if (failReads) throw StateError('dataModuleDisabled');
    return items[key];
  }

  @override
  void setItem(String key, String value) {
    items = <String, String>{...items, key: value};
  }

  Map<String, dynamic> get snapshot =>
      jsonDecode(items[CloudPrefsStore.cloudKey]!) as Map<String, dynamic>;
}

InMemorySharedPreferencesStore _local(Map<String, Object> values) =>
    InMemorySharedPreferencesStore.withData(values);

void main() {
  setUp(SharedPreferences.resetStatic);

  test('first run starts from local values and uploads on write', () async {
    final cloud = _FakeCloud();
    final local = _local(<String, Object>{'flutter.best': 120});
    SharedPreferencesStorePlatform.instance = await CloudPrefsStore.load(
      cloud,
      local,
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('best'), 120);

    await prefs.setBool('muted', true);
    expect(cloud.snapshot, <String, dynamic>{
      'flutter.best': 120,
      'flutter.muted': true,
    });
    expect((await local.getAll())['flutter.muted'], isTrue);
  });

  test('cloud snapshot wins over local values', () async {
    final cloud = _FakeCloud(<String, String>{
      CloudPrefsStore.cloudKey: jsonEncode(<String, Object>{
        'flutter.best': 900,
        'flutter.progress': '{"xp":40}',
        'flutter.list': <String>['a', 'b'],
        'flutter.ratio': 1.5,
      }),
    });
    SharedPreferencesStorePlatform.instance = await CloudPrefsStore.load(
      cloud,
      _local(<String, Object>{'flutter.best': 5, 'flutter.other': 'x'}),
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('best'), 900);
    expect(prefs.getString('progress'), '{"xp":40}');
    expect(prefs.getStringList('list'), <String>['a', 'b']);
    expect(prefs.getDouble('ratio'), 1.5);
    expect(prefs.getString('other'), isNull);
  });

  test('remove and clear reach the cloud snapshot', () async {
    final cloud = _FakeCloud();
    SharedPreferencesStorePlatform.instance = await CloudPrefsStore.load(
      cloud,
      _local(<String, Object>{'flutter.a': 1, 'flutter.b': 2}),
    );
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('a');
    expect(cloud.snapshot.keys, <String>['flutter.b']);
    await prefs.clear();
    expect(cloud.snapshot, isEmpty);
  });

  test('corrupt snapshots are ignored', () {
    expect(CloudPrefsStore.decode(null), isNull);
    expect(CloudPrefsStore.decode('not json'), isNull);
    expect(CloudPrefsStore.decode('[1,2]'), isNull);
    expect(CloudPrefsStore.decode('{"flutter.a":{"x":1},"flutter.b":2}'), {
      'flutter.b': 2,
    });
  });

  test('corrupt cloud value falls back to local values', () async {
    final cloud = _FakeCloud(<String, String>{
      CloudPrefsStore.cloudKey: '{broken',
    });
    final store = await CloudPrefsStore.load(
      cloud,
      _local(<String, Object>{'flutter.best': 7}),
    );
    expect(await store.getAll(), <String, Object>{'flutter.best': 7});
  });

  test('a failing data module surfaces so the caller keeps local', () async {
    final cloud = _FakeCloud()..failReads = true;
    expect(
      () => CloudPrefsStore.load(cloud, _local(<String, Object>{})),
      throwsStateError,
    );
  });
}
