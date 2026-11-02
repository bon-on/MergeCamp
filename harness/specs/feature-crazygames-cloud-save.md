---
id: feature-crazygames-cloud-save
title: CrazyGames 빌드의 진행도를 SDK Data 모듈(계정 저장)로 저장
status: active
owner: games
related_adrs:
  - adr-merge-camp-crazygames-web
related_contracts:
  - contract-merge-camp-crazygames
required_evidence:
  - flutter-analyze
  - flutter-tests
  - crazygames-web-build
  - harness-audit
---

# 기능 명세: CrazyGames 계정 저장

## Problem
모든 진행도(최고 점수, XP, 도감, 테마, 튜토리얼, 소리 설정)는 `shared_preferences`, 즉 브라우저 localStorage에만 있다.
CrazyGames에 로그인한 플레이어도 기기나 브라우저를 바꾸면 진행도가 사라진다. CrazyGames SDK의 Data 모듈은
로그인 사용자의 데이터를 계정에 동기화하고, 게스트는 localStorage에 두었다가 로그인 시 계정으로 옮긴다.

## Scope
- `--dart-define=CRAZYGAMES=true` 빌드에서 SDK 초기화가 성공하면 `SharedPreferencesStorePlatform.instance`를
  Data 모듈 기반 저장소로 바꾼다. 게임 코드의 저장소 클래스는 그대로 `SharedPreferences`를 쓴다.
- 모든 환경설정 값은 Data 모듈의 키 하나(`prefs_v1`, JSON 객체)에 저장한다. 같은 값을 기존 localStorage에도 계속 써서
  Data 모듈이 꺼져도 로컬 진행도가 남는다.
- 처음 실행할 때 `prefs_v1`이 없으면 기존 localStorage 값(이전 버전 플레이어의 진행도)으로 시작하고, 첫 쓰기 때 계정으로 올린다.
- 판 도중 로그인하면(`user.addAuthListener`) 계정 데이터가 바뀌므로 페이지를 다시 읽어 오래된 메모리 값이 계정 데이터를
  덮어쓰지 않게 한다.
- Data 모듈 호출이 실패하거나(`dataModuleDisabled` 등) SDK가 없으면 기존 localStorage 저장을 그대로 쓴다.
- 모바일, GitHub Pages, GamePix 빌드는 바뀌지 않는다.

## Acceptance Criteria
- CrazyGames 빌드에서 저장한 값이 Data 모듈 `prefs_v1`과 localStorage 양쪽에 기록된다.
- `prefs_v1`이 있으면 그 값이 localStorage 값보다 우선한다. 없으면 localStorage 값을 읽는다.
- 손상된 `prefs_v1`(JSON 아님, 객체 아님)은 무시하고 localStorage 값으로 대체한다.
- Data 모듈 `getItem`이 예외를 던지면 저장소를 바꾸지 않는다.
- SDK가 없거나 환경이 `crazygames`/`local`이 아니면 저장소를 바꾸지 않는다.
- 업로드 시 포털 제출 화면에서 Progress Save를 "Data Module 사용"으로 선택해야 한다(docs/crazygames.md에 기록).

## Constraints
- 새 패키지를 추가하지 않는다. 이미 잠금 파일에 있는 `shared_preferences_platform_interface`를 직접 의존성으로만 올린다.
- 저장 데이터는 1 MB 한도보다 훨씬 작아야 한다.

## Evidence
- `flutter analyze`, `flutter test`, `flutter test --platform chrome test/web`
- `tool/build_crazygames.sh`
- `node <harness-lab>/dist/index.js audit . --format md`
