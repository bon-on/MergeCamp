// Run with: flutter test --platform chrome test/web
@TestOn('browser')
library;

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
}
