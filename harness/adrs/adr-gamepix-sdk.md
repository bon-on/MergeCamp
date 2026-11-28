---
id: adr-gamepix-sdk
title: GamePix 빌드에 GamePix SDK v3 연동
status: accepted
related_specs:
  - feature-gamepix-sdk
  - feature-merge-camp-gamepix
---

# ADR: GamePix 빌드에 GamePix SDK v3 연동

## Context
`adr-merge-camp-gamepix-web`은 GamePix 빌드를 SDK 없이 만들기로 했다. GamePix는 게시는 했지만 "SDK integration approval"을 주지 않아 포털 노출이 제한된다.

## Decision
- `GAMEPIX=true` 웹 빌드는 `GamePixPlatform`(SDK v3, 수동 lifecycle)을 쓴다. SDK script는 `tool/build_gamepix.sh`가 Flutter bootstrap보다 먼저 넣고, 허용되는 외부 script는 이것 하나다.
- pause/resume으로 오디오를 끄고 켠다. 전면 광고는 기존 게임 오버 뒤 새 판 지점에서 2분 간격으로, 보상형 광고는 Second Wind에 쓴다. 설정은 `CloudPrefsStore`로 이름 붙은 localStorage 항목 하나에 둔다.
- `adr-merge-camp-gamepix-web`의 "SDK 없음" 부분만 대체한다. 외부 링크 금지, 번들 폰트, 상대 경로 규칙은 그대로다.

## Alternatives
- SDK 없이 유지: 작업은 없지만 SDK 승인과 추가 노출도 없다.
- 자동(legacy) lifecycle: 코드는 적지만 GamePix 분석(로딩 시간, 플레이까지 시간)이 부정확해지고 가이드상 순위 평가에 불리하다.
- shared_preferences_web 그대로: 플러그인이 키를 나열해 읽어서 GamePix 동기화가 진행을 복원하지 못한다.

## Consequences
- GamePix 번들이 integration.gamepix.com에 요청하고 GamePix 광고를 보여 준다.
- 기존 플레이어 진행은 첫 SDK 세션에서 나열한 로컬 키를 이름 붙은 항목으로 옮겨 유지한다.
