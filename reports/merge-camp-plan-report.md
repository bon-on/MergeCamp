# 하네스 계획 보고서

- 제목: MergeCamp 자연 세션 모바일 MVP 제공
- 명세: `/Users/junsik.park/sources/games/MergeCamp/harness/specs/feature-merge-camp-mvp.md`
- 상태: active

## 실행 순서

1. 기능 명세에서 의도와 수용 기준을 읽는다.
2. 구현 또는 설계 결정 전에 ADR `adr-merge-camp-flutter-foundation`을 읽는다.
3. 작업 단위 완료 기준을 확정하기 위해 계약 문서 `contract-merge-camp-mvp`를 읽는다.
4. 명세 요구사항을 저장소 제약과 골든 룰에 대조한다.
5. 수용 기준을 만족하는 가장 작은 구현 변경을 수행한다.
6. 필요한 증빙을 수집하고 에스컬레이션 포인트를 기록한다.

## 수용 기준

- 게임은 공유 Flutter 앱에서 iPhone과 Android 모두 실행된다.
- 빈 칸 탭은 다음 타일을 배치하고, 잘못된 탭은 거부된다.
- 인접한 같은 타일 3개 이상은 더 높은 티어로 머지된다.
- 눈에 보이는 고정 제한 시간이 없다.
- 배치, 머지, 경고 동작에서 효과음이 들린다.

## 제약

- MVP는 오프라인 단일 플레이를 유지한다.
- 햅틱은 플랫폼 피드백 API를 사용하고, 효과음은 번들 자산과 앱 셸 오디오 채널로 재생한다.
- 머지 규칙은 결정적이어야 하며 단위 테스트 가능해야 한다.

## 관련 ADR

- `adr-merge-camp-flutter-foundation`: MergeCamp MVP에 Flutter UI와 플랫폼 피드백 통합을 사용

## 관련 계약

- `contract-merge-camp-mvp`: MergeCamp MVP 구현

## 필수 증빙

- `flutter-tests`
- `harness-audit`
- `harness-plan`
- `flutter test`
- `node /Users/junsik.park/sources/harness-lab/dist/index.js audit . --format md`
- `node /Users/junsik.park/sources/harness-lab/dist/index.js plan harness/specs/feature-merge-camp-mvp.md --format text`

## 차단 사항

- 없음
