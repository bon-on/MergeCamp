---
id: feature-how-to-play-tutorial
title: MergeCamp 최초 실행 How to play 튜토리얼 제공
status: active
owner: games
related_adrs:
  - adr-merge-camp-flutter-foundation
related_contracts:
  - contract-merge-camp-mvp
required_evidence:
  - flutter-analyze
  - flutter-tests
  - web-build
  - harness-audit
---

# 기능 명세: MergeCamp 최초 실행 How to play 튜토리얼 제공

## Problem
첫 실행 플레이어가 목표, 입력 방식, 핵심 규칙을 알기 어렵다. 짧은 설명과 건너뛰기 옵션이 필요하다.

## Scope
- 최초 실행(플래그 미설정)에서만 3단계 "How to play" 오버레이 카드를 게임 위에 표시한다. 단계별 아이콘, 페이지 점, Skip / Next(마지막은 Play) 버튼을 제공한다.
- Skip 또는 Play는 오버레이를 닫고 `shared_preferences` 키 `tutorial_seen_v1`(bool)을 저장한다.
- 헤더의 `?` 버튼(툴팁 "How to play")으로 언제든 1단계부터 다시 연다. 게임 상태는 초기화하지 않는다.
- 키보드: Enter/Space 다음/Play, Escape 건너뛰기, 좌우 화살표 이전/다음. 오버레이가 열린 동안 이 키와 모든 게임 입력(탭, 방향키/WASD, X/E, R)은 게임에 전달되지 않는다.
- 플랫폼(CrazyGames SDK) 의미: 오버레이가 열려 있는 동안은 플레이 중이 아니다. 열릴 때(`?` 포함) `gameplayStop()`, 닫힐 때 `gameplayStart()`를 전환 시점에만 호출하며(중복 호출 없음), 최초 실행의 `gameplayStart()`는 튜토리얼이 닫힌 뒤에 호출한다.
- 저장소 실패는 플레이를 막지 않는다. 읽기 실패 시 튜토리얼을 표시하고, 쓰기 실패 시 그냥 닫는다.
- 문구는 영어이며 실제 존재하는 입력만 설명한다.

## Acceptance Criteria
- 플래그 미설정 시 오버레이가 표시되고 게임 입력이 차단된다.
- Next로 단계가 진행되고 마지막 단계는 Play이며, Play는 오버레이를 닫고 플래그를 저장한다.
- Skip과 Escape는 오버레이를 닫고 플래그를 저장한다.
- 플래그가 설정되어 있으면 오버레이가 표시되지 않는다.
- 오버레이 열림/닫힘에 맞춰 `gameplayStop()`/`gameplayStart()`가 순서대로 한 번씩만 호출된다.
- `?` 버튼은 1단계부터 다시 열며 보드 상태를 초기화하지 않는다.
- 390x844, 844x390, 1280x720에서 오버플로 없이 표시된다.

## Constraints
- MVP는 오프라인 단일 플레이를 유지한다. 저장소는 기기 로컬 `shared_preferences`만 사용한다.
- 저장소 접근은 주입 가능한 `HowToPlayStore`로 분리해 테스트가 실제 prefs에 의존하지 않게 한다.
- CrazyGames 빌드(`tool/build_crazygames.sh`)의 검사를 그대로 통과해야 한다.

## Evidence
- `flutter analyze`, `flutter test`
- `flutter build web --release --base-href /MergeCamp/`
- `node <harness-lab>/dist/index.js audit . --format md`
