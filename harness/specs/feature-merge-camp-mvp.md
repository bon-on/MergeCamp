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
- 새 타일은 낮은 티어일수록 자주 나오도록 가중치를 두어, 높은 티어를 직접 받기보다 쌓아 올리는 플레이가 중심이 되게 한다.
- 숫자 티어만 노출하는 대신 캠프 성장 체인으로 표현해 기존 3-merge 장르의 구체적 표현과 구분한다.
- 다음 타일 예측과 제한적 보드 정리 도구를 제공해 운 의존도를 줄이고 전술적 선택을 늘린다.

## Acceptance Criteria
- 게임은 공유 Flutter 앱에서 iPhone과 Android 모두 실행된다.
- 빈 칸 탭은 다음 타일을 배치하고, 잘못된 탭은 거부된다.
- 인접한 같은 타일 3개 이상은 더 높은 티어로 머지된다.
- 티어 상한이 열린 뒤에도 낮은 티어가 높은 티어보다 더 자주 생성된다.
- 게임에는 눈에 보이는 고정 제한 시간이 없다.
- 배치, 머지, 경고 동작에서 효과음이 들린다.
- HUD는 다음 타일 3개를 보여주며, 플레이어는 단일 다음 타일 랜덤성에만 의존하지 않는다.
- 빠른 연속 탭이 들어와도 한 번에 하나의 배치만 처리하며, HUD의 첫 번째 다음 타일이 실제 배치에 사용된다.
- 플레이어는 제한적으로 충전되는 캠프 도구로 점유 칸 하나를 비워 보드 압박에 대응할 수 있다.
- 화면 표현은 캠프 고유 성장명과 도구명을 사용하고, 타사 게임의 캐릭터/오브젝트 계층/튜토리얼 표현을 차용하지 않는다.

## Constraints
- MVP는 오프라인 단일 플레이를 유지한다.
- 햅틱은 플랫폼 피드백 API를 사용하고, 효과음은 번들 자산과 앱 셸 오디오 채널로 안정적으로 재생한다.
- 머지 규칙은 결정적이어야 하며 단위 테스트 가능해야 한다.

## Evidence
- `flutter test`
- `node /Users/junsik.park/sources/harness-lab/dist/index.js audit . --format md`
- `node /Users/junsik.park/sources/harness-lab/dist/index.js plan harness/specs/feature-merge-camp-mvp.md --format text`
