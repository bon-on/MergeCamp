---
id: adr-merge-camp-gamepix-web
title: GamePix 배포에 SDK 없는 GAMEPIX 빌드 플래그 사용
status: accepted
related_specs:
  - feature-merge-camp-gamepix
---

# ADR: GamePix 배포에 SDK 없는 GAMEPIX 빌드 플래그 사용

## Context

`adr-merge-camp-crazygames-web`는 CrazyGames 배포를 `CRAZYGAMES` 플래그와 SDK 어댑터로 풀었다. GamePix는 서드파티 SDK와 외부 리소스를 허용하지 않으므로 같은 어댑터를 쓸 수 없다. Flutter 웹은 `Roboto` 패밀리가 번들되지 않으면 런타임에 fonts.gstatic.com에서 폰트를 받는다.

## Decision

- `bool.fromEnvironment('GAMEPIX')`가 켜진 웹 빌드는 기존 `GamePlatform` 인터페이스의 no-op 구현(`NoopGamePlatform.gamePix()`)을 쓴다. 결과 등록은 꺼지고, CrazyGames 어댑터는 `CRAZYGAMES=true`에서만 선택되어 GamePix 번들에서는 트리 셰이킹으로 빠진다.
- index.html 후처리는 `tool/build_gamepix.sh`가 맡고 SDK script는 주입하지 않는다. 스크립트는 SDK/외부 URL/허브 링크/Roboto/zip 루트 구조를 검사하고 실패하면 중단한다.
- Roboto를 모든 빌드에 번들한다(영어 UI 기준, CJK 제외). 로딩 화면은 `web/index.html`의 CSS로 구현해 모든 웹 빌드가 공유한다.

## Consequences

- Pages, 모바일, CrazyGames 동작은 폰트와 로딩 화면을 제외하고 변하지 않는다.
- 번들에 Roboto 4개 파일(약 0.7MB)이 늘어난다.
- 엔진 코드(`flutter_bootstrap.js`, `main.dart.js`)에는 gstatic URL 문자열이 남지만 `useLocalCanvasKit`과 번들 폰트 때문에 요청되지 않는다.
