---
id: feature-quality-guideline-polish
title: CrazyGames 품질 가이드라인 맞춤 다듬기(자판 배치 무관 WASD, 머지 미리보기 표기, 데스크톱 알림 잘림)
status: active
owner: games
related_adrs:
  - adr-merge-camp-flutter-foundation
related_contracts:
  - contract-merge-camp-mvp
required_evidence:
  - flutter-analyze
  - flutter-tests
  - crazygames-web-build
  - independent-review
---

# 기능 명세: 품질 가이드라인 맞춤 다듬기

## Problem
2026-11-26 CrazyGames 품질 가이드라인(docs.crazygames.com/requirements/quality)과 재등록 드래프트 빌드(b69dcb4)를 대조했다.
fresh 저장소로 1100x620(데스크톱 iframe)과 390x760(모바일)에서 첫 실행을 따라가 보고 다음 문제를 찾았다.

- **자판 배치(Restricted keys).** 가이드는 키를 자판 배치에 맞추라고 하고, AZERTY에서 WASD가 ZQSD가 되는 예를 든다.
  보드 커서와 Shift 방향은 `LogicalKeyboardKey.keyW/A/S/D`(입력 문자)로 판단하므로, AZERTY 사용자는 W와 A 자리를 눌러도 움직이지 않는다.
- **알 수 없는 표기(쉬운 언어).** 커서나 호버로 머지를 미리 볼 때 대상 칸 아래에 "T2 / x1"이 10 px로 뜬다.
  T(tier)와 x(연쇄 단계)는 내부 용어이고, 결과 타일 그림은 칸에 이미 보인다.
- **데스크톱 알림 잘림.** 첫 머지에서 발견 배너("New Camp discovered!")와 토스트 2개(미션 완료, 환영 보너스)가 동시에 뜬다.
  wide 레이아웃의 알림 영역은 190 px로 고정되어 있고 넘치면 잘리므로, 1100x620에서 가장 최근 토스트("First merge! Welcome bonus …")가 아래로 잘린다.

## Scope
1. WASD는 물리 키 위치(`PhysicalKeyboardKey.keyW/A/S/D`)로 판단한다. 화살표는 그대로 논리 키다. 보드 커서 이동과 Shift 방향 선택에 모두 적용한다.
   R/C/X/E/Enter/Space/Esc는 그대로다(AZERTY에서도 같은 문자 위치). 논리 문자가 R/C/X/E인 키는 물리 위치가 WASD여도 그 문자 기능을 유지한다
   (예: Dvorak의 D 자리에서 오는 E는 Trail Axe다). 대상 배열은 QWERTY와 AZERTY이고, 다른 배열은 문자 바인딩이 우선한다.
2. 머지 미리보기 칸의 라벨은 연쇄가 2단계 이상일 때만 "Chain x{n}"으로, 11 px 이상으로 보인다. 칸이 좁아 들어가지 않으면 "x{n}"으로 줄이고,
   줄바꿈하지 않아 숫자가 잘리지 않는다. 1단계 머지는 라벨 없이 테두리와 결과 그림만 보인다.
   Semantics 라벨은 유지한다.
3. wide 레이아웃에서 발견 배너가 떠 있는 동안 토스트는 가장 최근 1개만 보인다. 배너가 없으면 지금처럼 최근 2개다.
   숨긴 토스트도 마운트된 채 타이머가 돌아서 수명이 그대로다. 배너가 사라진 뒤 다시 나타나거나 처음부터 재생되지 않는다.
   narrow/compact 레이아웃은 바꾸지 않는다.

## Constraints
- 머지 규칙, 점수, XP, 미션, 저장, SDK 호출은 바꾸지 않는다. 새 의존성이나 에셋은 없다.
- 키보드 단축키 안내 문구와 기존 키 동작(미국 배열)은 그대로다.

## Acceptance Criteria
- Q1: 물리 키 W/A/S/D(논리 문자가 Z/Q/S/D인 AZERTY 이벤트 포함)가 커서를 위/왼쪽/아래/오른쪽으로 옮긴다.
  물리 키 Z 위치에서 논리 'w'가 오는 이벤트(AZERTY의 W)는 커서를 옮기지 않는다. 기존 미국 배열 WASD 테스트도 통과한다.
  논리 E와 물리 D 조합(Dvorak)은 커서를 옮기지 않고 Trail Axe를 쓴다.
- Q2: Shift에서 캠프를 고른 뒤 AZERTY 물리 W 위치 키가 캠프를 위로 옮긴다.
- Q3: 1단계 머지 미리보기에는 "T2 / x1" 같은 텍스트가 없다. 2단계 이상 연쇄 미리보기는 큰 칸에서 "Chain x2"로 보이고, 글자 크기는 11 이상이다.
  390x844, 360x640, 640x360에서도 숫자가 줄바꿈 없이 칸 안에 보인다.
- Q4: 1100x620에서 fresh 첫 머지 직후 보이는 토스트가 모두 알림 영역 안에 완전히 들어간다(잘림 없음). 가장 최근 토스트("Welcome bonus")가 보인다.
  배너가 사라진 뒤(첫 머지 후 약 3초) 토스트가 다시 나타나지 않는다.
- Q5: `flutter analyze`와 `flutter test`가 통과한다.

## Requirement-to-check map
- Q1: `test/keyboard_controls_test.dart`.
- Q2: `test/camp_shift_test.dart`.
- Q3: `test/first_run_resume_test.dart`(미리보기 테스트 갱신), `test/keyboard_controls_test.dart`.
- Q4: `test/first_minute_rewards_test.dart`.
- Q5: CI 테스트 명령.

## Evidence
- reports/quality-guideline-polish-verification.md
