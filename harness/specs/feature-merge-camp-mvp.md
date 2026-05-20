---
id: feature-merge-camp-mvp
title: MergeCamp 자연 세션 모바일 MVP 제공
status: active
owner: games
related_adrs:
  - adr-merge-camp-flutter-foundation
related_contracts:
  - contract-merge-camp-mvp
required_evidence:
  - flutter-tests
  - harness-audit
  - harness-plan
---

# 기능 명세: MergeCamp 자연 세션 모바일 MVP 제공

## Problem
PocketOrbit는 플레이 지속성이 부족했다. 대체 게임은 더 느리고 전술적인 판단, 더 강한 보상 피드백, 그리고 강제 종료 타이머 없이 자연스럽게 압박이 올라가는 세션 구조가 필요하다.

## Scope
- 하나의 Flutter 코드베이스로 iPhone과 Android용 4x4 머지 퍼즐을 만든다.
- 고정 카운트다운이 아니라 보드 압박으로 게임 종료를 만든다.
- 배치, 머지, 잘못된 입력에 대해 효과음과 햅틱 피드백을 제공한다.
- 배치 누적에 따라 타일 종류를 늘려 일반적인 플레이 기준 약 3분 전후로 압박이 커지게 한다.

## Acceptance Criteria
- 게임은 공유 Flutter 앱에서 iPhone과 Android 모두 실행된다.
- 빈 칸 탭은 다음 타일을 배치하고, 잘못된 탭은 거부된다.
- 인접한 같은 타일 3개 이상은 더 높은 티어로 머지된다.
- 게임에는 눈에 보이는 고정 제한 시간이 없다.
- 배치, 머지, 경고 동작에서 효과음이 들린다.

## Constraints
- MVP는 오프라인 단일 플레이를 유지한다.
- 햅틱은 플랫폼 피드백 API를 사용하고, 효과음은 번들 자산과 앱 셸 오디오 채널로 안정적으로 재생한다.
- 머지 규칙은 결정적이어야 하며 단위 테스트 가능해야 한다.

## Evidence
- `flutter test`
- `node /Users/junsik.park/sources/harness-lab/dist/index.js audit . --format md`
- `node /Users/junsik.park/sources/harness-lab/dist/index.js plan harness/specs/feature-merge-camp-mvp.md --format text`
