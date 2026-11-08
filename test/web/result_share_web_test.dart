// Run with: flutter test --platform chrome test/web
@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_camp/src/game/share/result_share.dart';
import 'package:merge_camp/src/game/share/result_share_web.dart';
import 'package:merge_camp/src/platform/crazygames_platform.dart';
import 'package:merge_camp/src/platform/game_platform.dart';

void main() {
  test('each build flavor has its own share link', () {
    expect(
      CrazyGamesPlatform().shareLink,
      'https://www.crazygames.com/game/mergecamp-jvc',
    );
    expect(const NoopGamePlatform().shareLink, pagesShareLink);
    expect(pagesShareLink, 'https://bon-on.github.io/MergeCamp/');
    expect(const NoopGamePlatform.gamePix().shareLink, isNull);
  });

  test('browser helpers answer without throwing', () {
    expect(webCanDownload(), isTrue);
    expect(webCanShare(), isA<bool>());
    // Without a user gesture the copy may be refused; it must not throw.
    expect(webCopyFallback('MergeCamp'), isA<bool>());
    expect(const ResultShare().canSaveImage, isTrue);
  });

  test('Web Share failures are reported, not thrown', () async {
    // No user activation in the test runner: share is refused or missing.
    final status = await webShare(
      text: 'MergeCamp',
      png: Uint8List.fromList([1, 2, 3]),
      fileName: 'card.png',
    );
    expect(status, isNot(ShareStatus.done));
  });

  group('with a stubbed navigator.share', () {
    late JSObject navigator;
    final calls = <JSObject>[];

    setUp(() {
      navigator = globalContext.getProperty<JSObject>('navigator'.toJS);
      calls.clear();
    });

    tearDown(() {
      navigator.delete('share'.toJS);
      navigator.delete('canShare'.toJS);
    });

    void stub({required bool files, String? rejectWith}) {
      navigator.setProperty(
        'canShare'.toJS,
        ((JSObject data) => files.toJS).toJS,
      );
      navigator.setProperty(
        'share'.toJS,
        ((JSObject data) {
          calls.add(data);
          final promise = globalContext.getProperty<JSObject>('Promise'.toJS);
          if (rejectWith == null) {
            return promise.callMethod<JSPromise<JSAny?>>('resolve'.toJS);
          }
          final error = globalContext
              .getProperty<JSFunction>('DOMException'.toJS)
              .callAsConstructor<JSObject>('stub'.toJS, rejectWith.toJS);
          return promise.callMethod<JSPromise<JSAny?>>('reject'.toJS, error);
        }).toJS,
      );
    }

    test('attaches the card when files can be shared', () async {
      stub(files: true);
      final status = await webShare(
        text: 'hello',
        png: Uint8List.fromList([1, 2, 3]),
        fileName: 'card.png',
      );
      expect(status, ShareStatus.done);
      expect(calls.single.has('files'), isTrue);
      expect(calls.single.getProperty<JSString>('text'.toJS).toDart, 'hello');
    });

    test('shares text only when files are not supported', () async {
      stub(files: false);
      final status = await webShare(
        text: 'hello',
        png: Uint8List.fromList([1, 2, 3]),
        fileName: 'card.png',
      );
      expect(status, ShareStatus.done);
      expect(calls.single.has('files'), isFalse);
    });

    test('a closed share sheet is cancelled, other errors fail', () async {
      stub(files: false, rejectWith: 'AbortError');
      expect(
        await webShare(text: 'x', fileName: 'card.png'),
        ShareStatus.cancelled,
      );
      stub(files: false, rejectWith: 'NotAllowedError');
      expect(
        await webShare(text: 'x', fileName: 'card.png'),
        ShareStatus.failed,
      );
    });
  });
}
