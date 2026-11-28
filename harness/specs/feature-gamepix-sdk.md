---
id: feature-gamepix-sdk
title: MergeCamp GamePix SDK v3 연동
status: active
owner: games
related_adrs:
  - adr-gamepix-sdk
related_contracts:
  - contract-merge-camp-gamepix
required_evidence:
  - flutter-tests
  - flutter-web-tests
  - flutter-analyze
  - gamepix-web-build
---

# 기능 명세: MergeCamp GamePix SDK v3 연동

## Problem
GamePix가 SDK 없는 패키지를 게시했지만 "GamePix SDK integration approval"을 주지 않아 SDK 연동 게임이 받는 추가 노출을 받지 못한다. SDK v3 가이드(my.gamepix.com/sdk/doc)는 오디오를 끄는 pause/resume 처리, 수동 lifecycle 신호, 자연스러운 쉬는 지점의 광고, 이름으로 읽는 localStorage를 요구한다.

## Scope
- GamePix 웹 빌드(`--dart-define=GAMEPIX=true`)만: `GamePixPlatform` 어댑터와 `tool/build_gamepix.sh`.
- 제외: 게임 플레이/밸런스, CrazyGames/Pages/모바일 동작, 로그인, 멀티플레이, `happyMoment`/`sadMoment`, 로딩 퍼센트.

## Acceptance Criteria
- S1: GamePix `index.html`이 `window.GamePixConfig = { lifecycle: 'manual' }`을 두고 `https://integration.gamepix.com/sdk/v3/gamepix.sdk.js`를 한 번만, 둘 다 `flutter_bootstrap.js`보다 먼저 불러온다. 다른 외부 script/링크/URL은 없고, 있으면 빌드 스크립트가 실패한다.
- S2: 어댑터가 `pause`/`resume`을 등록한다. pause는 게임 오디오를 끄고(`isAudioMuted`), resume은 되돌린다. 같은 이벤트가 반복되어도 변화가 없다.
- S3: `lifecycle.loaded()`는 첫 Flutter 프레임 뒤 한 번, `lifecycle.gameStart()`는 게임 플레이가 시작될 때 `loaded()` 뒤에 보낸다. Player가 응답하지 않아도 10초 뒤 게임이 막히지 않는다.
- S4: 전면 광고(`ads.interstitial()`)는 기존 `showRunBreakAd` 지점(게임 오버 뒤 새 판)에서만, 게임 로드나 직전 광고 뒤 2분 안에는 나오지 않고, 동시에 두 번 요청하지 않는다. 실패/미송출/120초 무응답이어도 새 판이 시작된다.
- S5: 보상형 광고(`ads.reward()`, Second Wind)는 `success: true`일 때만 보상한다. SDK가 있을 때만 제안한다.
- S6: 설정은 `getItem`으로 이름을 지정해 읽는 localStorage 항목 하나(`mergecamp.prefs_v1`, GamePix가 여러 게임을 한 origin에서 서비스할 수 있어 게임별로 이름을 붙임)에 저장해 GamePix 저장 동기화가 진행 상황을 복원한다. SDK 이전에 저장한 진행(`flutter.` 키)은 첫 SDK 세션에서 유지되고, 그 키는 지우지 않는다.
- S7: SDK가 없으면(차단된 script, 직접 연 페이지) 예전 no-op처럼 광고와 기록 등록 안내가 없다.
- S8: CrazyGames와 Pages 번들에는 GamePix 어댑터 코드가, GamePix 번들에는 CrazyGames 코드가 없다.

## Constraints
- GamePix 규칙: 다른 서드파티 SDK 금지, 외부 링크 금지, 타이머 광고 금지, 광고 중 게임 정지와 음소거.
- SDK가 고장 나도 게임 시작과 진행을 막지 않는다.

## Stack Notes
- `lib/src/platform/gamepix_platform.dart`는 `CloudPrefsStore`를 접두어 붙은 localStorage 항목을 "cloud"로, 옛 키로 채운 메모리 미러와 함께, local stamp 없이 쓴다. 그래서 이름 붙은 항목이 항상 원본이다.
- shared_preferences_web은 `localStorage.key(i)`로 키를 나열하는데, GamePix 동기화는 이를 보지 못한다.

## Evidence
- `flutter analyze`, `flutter test`, `flutter test --platform chrome test/web`.
- `tool/build_gamepix.sh`, `tool/build_crazygames.sh` 성공, `GamePix` 문자열은 GamePix `main.dart.js`에만 있음.
