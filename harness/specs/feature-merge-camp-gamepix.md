---
id: feature-merge-camp-gamepix
title: MergeCamp GamePix 웹 배포
status: active
owner: games
related_adrs:
  - adr-merge-camp-gamepix-web
  - adr-merge-camp-crazygames-web
related_contracts:
  - contract-merge-camp-gamepix
required_evidence:
  - flutter-tests
  - flutter-analyze
  - gamepix-web-build
  - harness-audit
---

# 기능 명세: MergeCamp GamePix 웹 배포

## Problem

GamePix는 SDK 없이(또는 GamePix SDK만) 동작하는 HTML5 번들을 요구하고, 외부 링크/외부 콘텐츠/외부 리소스(CDN 폰트 포함)를 금지하며, 임의 iframe 크기에서 동작해야 한다. 기존 CrazyGames 번들은 CrazyGames SDK script와 어댑터를 포함하므로 그대로 올릴 수 없다.

## Scope

- `--dart-define=GAMEPIX=true`로 빌드한 웹 번들은 SDK 없는 `NoopGamePlatform.gamePix()`를 쓴다: 리더보드 등록 안내와 결과 업로드 없음(`allowsResultRegistration == false`). CrazyGames 어댑터는 `CRAZYGAMES=true`일 때만 선택된다.
- 웹 빌드의 `AdService`는 원래 no-op이라 광고가 나오지 않는다(AdMob은 모바일 전용).
- 효과음은 번들 자산을 그대로 재생한다. CrazyGames 어댑터의 midgame 광고, 광고 중 음소거, `muteAudio` 처리는 GamePix 번들에 없다.
- `tool/build_gamepix.sh`가 `build/gamepix/`와 `build/merge-camp-gamepix.zip`(index.html이 zip 루트)을 만든다: `--no-web-resources-cdn`, 상대 `<base href="./">`, 허브 내비게이션 바와 높이 제거, 템플릿 주석(문서 URL) 제거, 자체 검사(SDK/외부 URL/허브 링크 없음, viewport `user-scalable=no`, `touch-action: none`, FontManifest의 Roboto).
- 모든 웹 빌드(Pages, CrazyGames, GamePix)에 Roboto(400/500/700/900)를 `assets/fonts/`로 번들해 Flutter가 fonts.gstatic.com에서 폰트를 받지 않게 한다. 라이선스는 `assets/fonts/Roboto_LICENSE.txt`. 포털 빌드의 UI는 영어이므로 CJK 폰트는 넣지 않는다.
- `web/index.html`에 외부 자산 없는 CSS 로딩 화면(스피너 + 게임 이름)을 두고 Flutter 첫 프레임(`flutter-first-frame`)에서 제거한다. Pages, CrazyGames, GamePix 모두 해당한다.

제외 범위: 게임 플레이/밸런스 변경, GamePix SDK 연동, CrazyGames 번들 동작 변경(폰트와 로딩 화면 제외), 포털 업로드와 제출.

## Acceptance Criteria

- `flutter analyze`, `flutter test`가 통과하고, `NoopGamePlatform.gamePix()`가 결과 등록을 막는지 테스트가 검증한다.
- `tool/build_gamepix.sh`가 성공하고 `build/merge-camp-gamepix.zip`의 루트에 `index.html`이 있다.
- GamePix 번들 `index.html`에는 `<base href="./">`가 있고, `crazygames`, `bon-on.github.io`, `http(s)://` URL이 없으며, 내비게이션 높이는 0이다. 번들에 `crazygames-sdk` 참조가 없다.
- `main.dart.js`의 `crazygames` 문자열 수를 보고한다(목표 0).
- `assets/FontManifest.json`에 `Roboto` 패밀리가 있고, headless Chrome 로드 중 외부 호스트 요청이 없다.
- 640x480과 360x640에서 가로/세로 오버플로 없이 표시된다.
- `tool/build_crazygames.sh`와 Pages 빌드(`--base-href /MergeCamp/`)가 계속 성공하고, Pages 빌드에는 SDK script가 없다.

## Constraints

- 게임 플레이는 SDK와 네트워크 없이 동작해야 한다.
- 새 pub 의존성을 추가하지 않는다.
- 모바일 AdMob 경로는 변경하지 않는다.

## Evidence

- `flutter analyze`, `flutter test`, `flutter test --platform chrome test/web`
- `tool/build_gamepix.sh`, `tool/build_crazygames.sh`, `flutter build web --release --base-href /MergeCamp/`
- `node <harness-lab>/dist/index.js audit . --format md`
- `reports/merge-camp-gamepix-verification.md`
