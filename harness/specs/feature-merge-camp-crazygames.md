---
id: feature-merge-camp-crazygames
title: MergeCamp CrazyGames 웹 배포
status: active
owner: games
related_adrs:
  - adr-merge-camp-crazygames-web
related_contracts:
  - contract-merge-camp-crazygames
required_evidence:
  - flutter-tests
  - flutter-analyze
  - crazygames-web-build
  - harness-audit
---

# 기능 명세: MergeCamp CrazyGames 웹 배포

## Problem

MergeCamp 웹 빌드는 GitHub Pages에서 광고 없이만 실행된다. CrazyGames 포털에 올려 트래픽과 광고 수익을 얻으려면 CrazyGames HTML5 SDK v3 연동, 상대 경로 번들, 데스크톱 화면 대응이 필요하다.

## Scope

- `--dart-define=CRAZYGAMES=true`로 빌드한 웹 번들에서만 CrazyGames SDK를 사용한다.
- GitHub Pages 빌드(`--base-href /MergeCamp/`)는 지금처럼 광고와 SDK 없이 유지한다.
- 모바일 네이티브 빌드의 AdMob 경로는 변경하지 않는다.
- SDK 연동 범위:
  - `SDK.init()` 후 `environment`가 `crazygames` 또는 `local`일 때만 SDK를 호출한다.
  - 첫 프레임 이후 `gameplayStart`, 게임 오버 시 `gameplayStop`을 호출한다.
  - 게임 오버 후 플레이어가 재시작하면 `midgame` 광고를 요청하고, 광고가 끝나거나 실패한 뒤 새 판을 시작하고 `gameplayStart`를 호출한다.
  - 광고 재생 중과 SDK `muteAudio` 설정이 켜진 동안 효과음을 끈다.
- 웹에서도 번들 효과음 자산을 재생한다.
- 데스크톱 가로 화면에서 플레이 영역 폭을 제한해 가운데 정렬하고, 타일 위에서 클릭 커서를 보여준다.
- CrazyGames 번들에서는 외부 링크를 두지 않는다: Bon-on 게임 허브 내비게이션 바(`feature-game-hub-navigation`)를 빌드 산출물에서 제거하고, 리더보드 등록 안내(`feature-post-game-leaderboard`)를 띄우지 않는다.
- 상대 경로 `<base href="./">`와 SDK script 태그를 넣은 CrazyGames 업로드 번들(폴더와 zip)을 만드는 빌드 스크립트를 제공한다.

제외 범위:

- 보상형 광고, 배너 광고, CrazyGames Data/User 모듈.
- 키보드 조작(클릭 기반 게임이라 마우스로 전체 플레이가 가능하다).
- 머지 규칙, 난이도, 점수 변경.
- CrazyGames 개발자 포털 업로드와 제출.

## Acceptance Criteria

- `flutter test`와 `flutter analyze`가 통과한다.
- `tool/build_crazygames.sh`가 `build/crazygames/`와 `build/merge-camp-crazygames.zip`을 만든다.
- CrazyGames 번들의 `index.html`은 `<base href="./">`와 `https://sdk.crazygames.com/crazygames-sdk-v3.js` script를 `flutter_bootstrap.js`보다 먼저 포함한다.
- CrazyGames 번들은 파일 1500개 이하, 전체 크기 50MB 이하다.
- `flutter build web --release --base-href /MergeCamp/` 결과물에는 CrazyGames SDK script가 없다.
- CrazyGames 번들 `index.html`에는 게임 허브 내비게이션 바와 `bon-on.github.io` 링크가 없고, 내비게이션 높이는 0이다.
- CrazyGames 빌드에서는 게임 오버 후 리더보드 등록 안내가 뜨지 않는다. GitHub Pages와 모바일 빌드에서는 그대로 뜬다.
- SDK가 없거나 `environment`가 `disabled`이거나 SDK 호출이 실패해도 게임은 광고 없이 계속 플레이된다.
- 게임 오버 후 재시작은 광고 요청이 끝날 때까지 새 판을 시작하지 않고, 진행 중 재시작은 광고를 요청하지 않는다.
- 위젯 테스트로 `gameplayStart`/`gameplayStop`/광고 요청 순서를 검증한다.

## Constraints

- 게임 플레이는 SDK와 네트워크 없이도 동작해야 한다(오프라인 단일 플레이 유지).
- 머지 규칙과 난이도 상승은 이 작업에서 변경하지 않는다.
- CrazyGames 번들에는 다른 광고 네트워크를 넣지 않는다.
- 새 pub 의존성을 추가하지 않는다(`dart:js_interop`, `dart:ui_web` 사용).

## Evidence

- `flutter analyze`
- `flutter test`
- `flutter test --platform chrome test/web`
- `tool/build_crazygames.sh`
- `node <harness-lab>/dist/index.js audit . --format md`
- `reports/merge-camp-crazygames-verification.md`
