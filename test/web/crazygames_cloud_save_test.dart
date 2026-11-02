// Run with: flutter test --platform chrome test/web
@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_camp/src/platform/crazygames_platform.dart';
import 'package:merge_camp/src/platform/crazygames_prefs_store.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

/// Fake SDK whose Data module stores items in [items].
class _FakeSdk {
  _FakeSdk({
    this.environment = 'local',
    this.failData = false,
    this.username,
    this.userFails = false,
  }) {
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
        ((JSString key, JSString value) => items[key.toDart] = value.toDart)
            .toJS,
      );
    final user = JSObject()
      ..setProperty(
        'getUser'.toJS,
        (() {
          if (userFails) {
            return Future<JSAny?>.error('network').toJS;
          }
          return Future<JSAny?>.value(_user(username)).toJS;
        }).toJS,
      )
      ..setProperty(
        'addAuthListener'.toJS,
        ((JSFunction listener) => authListener = listener).toJS,
      );
    final sdk = JSObject()
      ..setProperty('environment'.toJS, environment.toJS)
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

  final String environment;
  final bool failData;
  final String? username;
  final bool userFails;
  final Map<String, String> items = <String, String>{};
  JSFunction? authListener;

  static JSObject? _user(String? name) => name == null
      ? null
      : (JSObject()..setProperty('username'.toJS, name.toJS));

  void auth(String? name) => authListener!.callAsFunction(null, _user(name));
}

void main() {
  late SharedPreferencesStorePlatform original;
  setUp(() {
    original = InMemorySharedPreferencesStore.empty();
    SharedPreferencesStorePlatform.instance = original;
    globalContext
        .getProperty<JSObject>('localStorage'.toJS)
        .callMethod<JSAny?>(
          'removeItem'.toJS,
          CloudPrefsStore.localStampKey.toJS,
        );
  });
  tearDown(() => globalContext.delete('CrazyGames'.toJS));

  test('working data module becomes the preferences store', () async {
    final sdk = _FakeSdk(username: 'ana');
    sdk.items[CloudPrefsStore.cloudKey] =
        '{"rev":2,"owner":"ana","values":{"flutter.best":42}}';
    await CrazyGamesPlatform().initialize();

    final store = SharedPreferencesStorePlatform.instance;
    expect(store, isA<CloudPrefsStore>());
    expect(await store.getAll(), <String, Object>{'flutter.best': 42});
    await store.setValue('Int', 'flutter.best', 50);
    expect(
      sdk.items[CloudPrefsStore.cloudKey],
      '{"rev":3,"owner":"ana","values":{"flutter.best":50}}',
    );
  });

  test('failing data module keeps the local store', () async {
    _FakeSdk(failData: true);
    await CrazyGamesPlatform().initialize();
    expect(SharedPreferencesStorePlatform.instance, same(original));
  });

  test('unknown environment keeps the local store', () async {
    _FakeSdk(environment: 'disabled');
    await CrazyGamesPlatform().initialize();
    expect(SharedPreferencesStorePlatform.instance, same(original));
  });

  test('unknown initial user keeps local and reloads on any auth', () async {
    final sdk = _FakeSdk(userFails: true);
    var reloads = 0;
    await (CrazyGamesPlatform()..reloadOverride = () => reloads++).initialize();
    expect(SharedPreferencesStorePlatform.instance, same(original));
    sdk.auth(null);
    expect(reloads, 1);
  });

  test('only a different player triggers a reload', () async {
    final sdk = _FakeSdk(username: 'ana');
    var reloads = 0;
    await (CrazyGamesPlatform()..reloadOverride = () => reloads++).initialize();

    sdk.auth('ana');
    expect(reloads, 0);
    sdk.auth('bob');
    expect(reloads, 1);
    sdk.auth(null);
    expect(reloads, 2);
  });
}
