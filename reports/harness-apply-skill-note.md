# Harness Apply 스킬 메모

- 사용한 참조:
  - `harness/manifest.json`
  - `harness/specs/feature-merge-camp-mvp.md`
  - `harness/adrs/adr-merge-camp-flutter-foundation.md`
  - `harness/contracts/contract-merge-camp-mvp.md`
  - `harness/rules/constraints.md`
  - `harness/rules/golden-rules.md`
- 제약:
  - 게임은 오프라인 단일 플레이를 유지한다.
  - 배치 기반 압박과 필수 오디오 피드백을 유지한다.
- 충돌 또는 공백:
  - 이 장비에는 Android cmdline-tools가 없어 Android 실기기 검증 증빙은 아직 완전하지 않다.
- 에스컬레이션:
  - 최종 Android 기기 QA 전에는 전체 Android SDK command-line tools 설치가 필요하다.
