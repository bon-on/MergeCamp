import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web game has an accessible return link to the game hub', () {
    final html = File('web/index.html').readAsStringSync();

    expect(html, contains('href="https://bon-on.github.io/"'));
    expect(html, contains('aria-label="게임 선택 화면으로 돌아가기"'));
    expect(html, contains('← 게임 목록'));
    expect(html, contains('z-index: 2147483647'));
    expect(html, contains('env(safe-area-inset-top)'));
    expect(html, contains('class="games-nav-bar"'));
    expect(html, contains('id="flutter-host"'));
    expect(html, contains('inset: var(--games-nav-height) 0 0 0'));
    expect(html, contains('name="viewport"'));
    expect(html, contains('width=device-width'));
    final bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();
    expect(bootstrap, contains("querySelector('#flutter-host')"));
  });
}
