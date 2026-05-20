---
id: adr-merge-camp-flutter-foundation
title: MergeCamp MVP에 Flutter UI와 플랫폼 피드백 통합 사용
status: accepted
related_specs:
  - feature-merge-camp-mvp
---

# ADR: MergeCamp MVP에 Flutter UI와 플랫폼 피드백 통합을 사용

## Context
MergeCamp는 대부분 탭 기반으로 진행되는 그리드 퍼즐이다. 구현 리스크의 핵심은 렌더링 규모보다 게임 규칙의 명확성과 피드백 감각에 있다.

## Decision
보드와 HUD는 표준 Flutter 위젯으로 구성하고, 보드 상태, 압박 상승, 점수, 머지 해석은 순수 Dart 컨트롤러에 둔다. 햅틱은 플랫폼 피드백 API를 사용하고, 효과음은 번들 자산을 앱 셸 오디오 채널로 재생한다.

## Consequences
- 전체 MVP는 위젯 테스트와 단위 테스트로 검증하기 쉬운 구조를 유지한다.
- 효과음은 기기별 시스템 클릭음 의존 대신 앱 자산 기준으로 일관되게 관리된다.
- 이후 시각적 완성도를 높여도 머지 규칙을 다시 쓰지 않아도 된다.
