---
id: contract-merge-camp-mvp
title: MergeCamp MVP 구현
status: active
related_specs:
  - feature-merge-camp-mvp
  - feature-sound-effects
evidence_files:
  - reports/merge-camp-audit-report.md
  - reports/merge-camp-plan-report.md
---

# 계약: MergeCamp MVP 구현

## Goal
공유 Flutter 앱에서 보드 압박, 머지 점수, 필수 오디오 피드백을 포함하는 MergeCamp MVP 루프를 완성한다.

## Scope
- repo-kit 샘플 문서를 MergeCamp 전용 하네스 문서로 교체한다.
- 보드 로직, 배치 기반 압박, 점수 상승을 구현한다.
- 다음 타일 미리보기, 제한 도구, 캠프 고유 성장 표현을 추가한다.
- 핵심 동작에 효과음과 햅틱 피드백을 추가한다.
- 머지 규칙과 셸 렌더링을 테스트로 덮는다.

## Done Criteria
- 보드는 배치를 받고, 머지를 해석하며, 종료 상태를 정상 처리한다.
- 고정 타이머 없이도 일반적인 플레이 기준 약 3분 전후로 압박이 체감되게 올라간다.
- 다음 타일 예측과 제한 도구가 테스트 가능한 컨트롤러 상태로 제공된다.
- 캠프 테마 표현은 숫자 티어 단독 표기보다 우선해 표시된다.
- `flutter test`가 통과한다.
- 하네스 audit/plan 보고서를 이 저장소 기준으로 재생성한다.

## Verification
- `flutter test`를 실행한다.
- `node <harness-lab>/dist/index.js audit . --format md`를 실행한다.
- `node <harness-lab>/dist/index.js plan harness/specs/feature-merge-camp-mvp.md --format text`를 실행한다.

## Evidence References
- reports/merge-camp-audit-report.md
- reports/merge-camp-plan-report.md
