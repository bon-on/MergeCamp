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
    expect(html, contains('right: max(12px, env(safe-area-inset-right))'));
    expect(html, isNot(contains('left: max(12px, env(safe-area-inset-left))')));
  });
}
