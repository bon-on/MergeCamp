---
id: adr-merge-camp-crazygames-web
title: CrazyGames 배포에 빌드 플래그와 플랫폼 어댑터 사용
status: accepted
related_specs:
  - feature-merge-camp-gamepix
  - feature-merge-camp-crazygames
  - feature-sound-effects
  - feature-retention-polish
  - feature-crazygames-cloud-save
  - feature-mobile-perf
  - feature-camp-stickers
  - feature-next-goal-share
  - feature-daily-camp
  - feature-merge-feel-timing
  - feature-instant-first-run
  - feature-second-wind
  - feature-large-screen-scale
---

# ADR: CrazyGames 배포에 빌드 플래그와 플랫폼 어댑터 사용

## Context

`adr-merge-camp-pwa-pages`는 웹 빌드를 광고 없이 GitHub Pages에 배포하도록 결정했다. CrazyGames 배포는 같은 Flutter 웹 코드에서 SDK 광고와 gameplay 이벤트가 필요하지만, GitHub Pages 빌드는 광고 없는 상태로 남아야 한다. CrazyGames는 iframe 안의 임의 경로에서 번들을 서빙하므로 절대 경로 base href를 쓸 수 없다.

## Decision

- 컴파일 타임 상수 `bool.fromEnvironment('CRAZYGAMES')`로 CrazyGames 빌드를 구분한다. 플래그가 없으면 웹 빌드는 기존처럼 no-op 플랫폼을 쓴다.
- 게임 화면은 `GamePlatform` 인터페이스(`gameplayStart`, `gameplayStop`, `showRunBreakAd`, `isAudioMuted`, `allowsResultRegistration`)에만 의존한다. 웹 + 플래그일 때만 `dart:js_interop` 기반 CrazyGames 어댑터를 쓰고, 그 외에는 no-op 구현을 쓴다. 조건부 import는 `dart.library.js_interop`을 기준으로 한다.
- 모바일 AdMob 경로(`AdService`)는 그대로 두고, CrazyGames 광고는 `GamePlatform`으로만 요청한다.
- SDK script와 상대 base href는 `web/index.html`에 넣지 않고 `tool/build_crazygames.sh`가 빌드 산출물에만 주입한다.
- 포털 정책상 외부 링크를 두지 않는다. 빌드 스크립트가 게임 허브 내비게이션 바를 산출물에서 지우고 높이 변수를 0으로 바꾼다. 리더보드 등록 안내는 `GamePlatform.allowsResultRegistration`으로 막는다(CrazyGames 어댑터는 `false`).
- 웹 효과음은 네이티브 셸 채널 대신 브라우저 오디오 요소로 같은 번들 자산을 재생한다.
- 결과 공유(feature-next-goal-share)는 `GamePlatform.shareLink`로 빌드별 링크를 정한다. CrazyGames 어댑터는 자체 게임 페이지 URL을 돌려주고, 그 URL은 공유 텍스트 안의 글자일 뿐 게임이 열거나 이동하지 않는다. 그래서 위의 "외부 링크 없음"(플레이어를 포털 밖으로 보내는 링크와 내비게이션 금지)과 충돌하지 않는다고 본다. 공유는 SDK 광고나 gameplay 이벤트를 부르지 않는다.

## Consequences

- GitHub Pages, 모바일, CrazyGames 빌드가 하나의 코드베이스에서 서로 영향을 주지 않는다.
- SDK 로딩이나 호출에 실패하면 no-op으로 떨어져 오프라인 플레이가 유지된다.
- CrazyGames용 index.html 변경은 빌드 스크립트의 문자열 치환에 의존하므로, 스크립트가 치환 결과를 검증하고 실패하면 중단해야 한다.
- 웹 효과음 경로는 `constraints.md`의 "네이티브 셸 오디오 채널" 규칙을 웹 셸 오디오로 확장한 것이다.
