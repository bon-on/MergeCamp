// Run with: flutter test --platform chrome test/web
@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_camp/src/platform/crazygames_platform.dart';
import 'package:merge_camp/src/platform/crazygames_prefs_store.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

/// Installs a fake SDK whose Data module stores items in [items].
void _installSdk(Map<String, String> items, {bool failData = false}) {
  final game = JSObject()
    ..setProperty('gameplayStart'.toJS, (() {}).toJS)
    ..setProperty('gameplayStop'.toJS, (() {}).toJS)
    ..setProperty('addSettingsChangeListener'.toJS, ((JSFunction _) {}).toJS);
  final data = JSObject()
    ..setProperty(
      'getItem'.toJS,
      ((JSString key) {
        if (failData) throw 'dataModuleDisabled'.toJS;
        return items[key.toDart]?.toJS;
      }).toJS,
    )
    ..setProperty(
      'setItem'.toJS,
      ((JSString key, JSString value) => items[key.toDart] = value.toDart).toJS,
    );
  final user = JSObject()
    ..setProperty('getUser'.toJS, (() => Future<JSAny?>.value().toJS).toJS)
    ..setProperty('addAuthListener'.toJS, ((JSFunction _) {}).toJS);
  final sdk = JSObject()
    ..setProperty('environment'.toJS, 'local'.toJS)
    ..setProperty('game'.toJS, game)
    ..setProperty('ad'.toJS, JSObject())
    ..setProperty('data'.toJS, data)
    ..setProperty('user'.toJS, user)
    ..setProperty('init'.toJS, (() => Future<void>.value().toJS).toJS);
  globalContext.setProperty(
    'CrazyGames'.toJS,
    JSObject()..setProperty('SDK'.toJS, sdk),
  );
}

void main() {
  late SharedPreferencesStorePlatform original;
  setUp(() {
    original = InMemorySharedPreferencesStore.empty();
    SharedPreferencesStorePlatform.instance = original;
  });
  tearDown(() => globalContext.delete('CrazyGames'.toJS));

  test('working data module becomes the preferences store', () async {
    final items = <String, String>{
      CloudPrefsStore.cloudKey: '{"flutter.best":42}',
    };
    _installSdk(items);
    await CrazyGamesPlatform().initialize();

    final store = SharedPreferencesStorePlatform.instance;
    expect(store, isA<CloudPrefsStore>());
    expect(await store.getAll(), <String, Object>{'flutter.best': 42});
    await store.setValue('Int', 'flutter.best', 50);
    expect(items[CloudPrefsStore.cloudKey], '{"flutter.best":50}');
  });

  test('failing data module keeps the local store', () async {
    _installSdk(<String, String>{}, failData: true);
    await CrazyGamesPlatform().initialize();
    expect(SharedPreferencesStorePlatform.instance, same(original));
  });
}
