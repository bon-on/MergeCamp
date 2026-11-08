---
id: feature-first-minute-rewards
title: MergeCamp 첫 1분 안의 보상(환영 보너스, 첫 판 중 레벨업, 첫 판 기념 배너)
status: active
owner: games
related_adrs:
  - adr-merge-camp-flutter-foundation
  - adr-run-snapshot
related_contracts:
  - contract-merge-camp-mvp
required_evidence:
  - flutter-analyze
  - flutter-tests
  - web-build
  - crazygames-web-build
  - gamepix-web-build
  - harness-audit
---

# 기능 명세: 첫 1분 안의 보상

## Problem
CrazyGames 방문자의 2/3가 1분 안에 떠난다(1분 이상 플레이 33%). 지금 새 플레이어가 첫 판에서 받는 눈에 보이는 보상은
처음부터 붙어 있는 Pennant 스티커, 미션 토스트, 발견 배너뿐이다. 레벨업과 그 스티커는 판이 끝나야(`CampProgress.applyRun`) 적용되고,
첫 판의 XP로는 Lv2(230 XP)에 닿지 못하는 경우가 많다. 새 플레이어가 약 60초 안에 레벨업과 새 스티커를 보게 한다.

## Scope
1. 환영 보너스(한 번만)
   - 대상: 저장된 XP와 최고 점수가 모두 0이고 환영 보너스를 아직 받지 않은 플레이어. 기존 플레이어는 대상이 아니다.
   - 그 플레이어의 판에서 첫 머지가 일어나면 `welcomeBonusXp`(150 XP)를 저장된 XP에 바로 더하고, `welcomeRun` 표시를 켜서 즉시 저장한다.
     토스트 "First merge! Welcome bonus +150 camp XP"를 보여 준다.
   - 보너스는 판의 XP와 별개다. 판의 XP는 지금처럼 판이 끝날 때 한 번만 더해진다.
2. 첫 판 중 레벨업(환영 판 전용)
   - 환영 판(`welcomeRun`이 켜진 동안) 동안 매 배치 뒤에 실시간 XP = 저장된 XP + 이 판에서 지금까지 번 XP(`CampProgress.runXp`, `applyRun`과 같은 공식)를 계산한다.
   - 실시간 레벨이 `stickersSeen`보다 높아지면 Lv2(`welcomeLevel`)까지만 판 도중에 레벨업한다: Pine Tree를 첫 빈 슬롯에 바로 붙이고
     `stickersSeen`을 2로 올려 즉시 저장한다. 레벨업 효과음(`levelUp`)과 스티커 그림이 있는 토스트 "Level up! Lv 2 - New sticker: Pine Tree"를 보여 준다.
     Lv3 이상은 판이 끝날 때 기존 방식으로 처리한다.
   - 환영 판 동안 HUD의 레벨/XP 바는 실시간 XP로 보여 준다(저장값은 바꾸지 않는다).
   - 스티커 보유 레벨(`stickerLevel`)은 max(level, min(stickersSeen, 2))다. 그래서 판 도중에 받은 Pine Tree는 저장된 XP가 아직 Lv1이어도
     다시 로드한 뒤 남아 있다. Lv2 이상인 기존 플레이어에게는 차이가 없다.
   - 판 끝(`applyRun`)은 `stickersSeen` 이하 레벨의 스티커를 다시 붙이거나 알리지 않는다. `RunOutcome.announcedLevel`(= max(levelBefore, stickersSeen))을
     넘은 레벨만 레벨업 칩, 스티커 칩, 테마 해금, 레벨업 효과음, 재시작 토스트를 만든다. 판 끝에 `welcomeRun`을 끈다.
   - 판 도중 스냅샷(`activeRun`, adr-run-snapshot)의 형식은 바꾸지 않는다. 다시 로드하면 `welcomeRun`과 `stickersSeen`은 메타 필드로 남아 있으므로
     판 도중 레벨업이 다시 일어나지 않고, 판 끝에 XP가 한 번만 더해진다.
3. 첫 판 기념 배너(환영 대상 또는 환영 판에서만)
   - 첫 머지(보너스 토스트로 대신), 첫 4개 이상 동시 머지 "Big merge! 4+ camps at once", 첫 연쇄 "First chain!", 첫 Trail Axe 사용 "Trail Axe cleared a plot!".
   - 비차단 토스트이며 같은 판에서 한 번씩만 뜬다. 같은 배치에서 미션이 끝났거나 환영 보너스 토스트가 떴으면 그 기념은 본 것으로만 표시하고
     토스트를 띄우지 않는다(토스트는 최근 2개만 보이므로 미션 토스트를 밀어내지 않기 위해). 기념 토스트는 `mission` 효과음을 재사용한다. 새 오디오 파일은 없다.
   - 다시 로드한 판에서는 컨트롤러 상태(머지 수, 최장 연쇄)로 이미 지난 기념을 건너뛴다. 4개 이상 머지와 도끼 기념은 다시 로드 뒤 한 번 더 뜰 수 있다.
4. 저장: `camp_progress_v1`에 `welcomeRun`(bool, 켜졌을 때만 기록)을 추가한다. 없으면 false다. 보너스 지급 여부는 XP가 0보다 큰 것으로 판단한다.

## Acceptance Criteria
- 새 플레이어: 안내 연습 머지 직후 보너스 150 XP가 저장되고 `welcomeRun`이 켜진다. 기존 플레이어(XP 또는 최고 점수 > 0)는 보너스를 받지 않는다.
- 새 플레이어의 대본 첫 판(연습 머지 + 시작 미션 "Place 6 tiles")에서 판이 끝나기 전에 Lv2 토스트가 보이고, 보드 둘레에 Pennant와 Pine Tree 두 스티커가 붙으며 저장된다.
- 판 도중 레벨업 뒤 판이 끝나면 XP는 보너스 + 판 XP와 정확히 같고(이중 계산 없음), Pine Tree는 한 번만 붙고, 요약에 Lv2 레벨업/스티커 칩이 다시 나오지 않는다.
- 판 도중 레벨업 뒤 다시 로드해도 Pine Tree가 남아 있고 판이 복원되며, 다시 레벨업하지 않고, 판 끝 XP도 한 번만 더해진다.
- 기존 플레이어의 판 흐름(판 끝 레벨업, 스티커 칩, 재시작 토스트, HUD XP)은 변하지 않는다.
- 첫 판 기념은 환영 판에서만 한 번씩 뜨고, 기존 플레이어에게는 뜨지 않는다.
- 머지 규칙, 점수, 판 XP 공식, 레벨 곡선, 광고 흐름은 바뀌지 않는다. lib/ 문자열은 영어 ASCII다. 기존 테스트가 모두 통과한다.

## Constraints
- 새 패키지, 새 오디오 파일, 광고 추가 없음. `activeRun` 형식 변경 없음.
- 판 도중 레벨업은 환영 판의 Lv2 하나뿐이다. 일반 플레이의 레벨업 시점은 그대로 판 끝이다.

## Decisions
- 보너스 크기 150 XP: 연습 머지(약 7 XP) + 첫 미션 30 XP 뒤 실시간 XP 약 187, 6번째 배치에서 두 번째 시작 미션(30)과 참가 XP(20)가 더해져 230을 넘는다.
  즉 두 번째 시작 미션 순간에 Lv2가 된다(약 30~60초). 보너스는 첫 머지 때 주므로 바로 떠난 방문자에게는 주지 않는다.
- 판 도중 XP를 저장된 XP에 미리 더하지 않는다(스냅샷 형식을 바꾸지 않고 이중 계산을 막기 위해). 대신 스티커 보유를 `stickersSeen`(최대 2)로 보장한다.

## Plan and check mapping
| Requirement | Files | Verification |
|---|---|---|
| runXp, welcome bonus, live level-up, stickerLevel, announcedLevel, JSON | `lib/src/meta/camp_progress.dart` | `test/first_minute_rewards_test.dart` (unit) |
| Screen flow, HUD live XP, toasts, milestones | `lib/src/game/merge_camp_screen.dart`, `ui/banners.dart`, `ui/decor_overlay.dart`, `ui/run_summary_overlay.dart` | `test/first_minute_rewards_test.dart` (widget) |
| Existing players unchanged | same | 기존 `decor_stickers_test.dart`, `ui_screen_test.dart`, 새 위젯 테스트 |

## Evidence
- `flutter analyze`, `flutter test`, `flutter test --platform chrome test/web`
- `tool/build_crazygames.sh`, `tool/build_gamepix.sh`
- `node <harness-lab>/dist/index.js audit . --format md`

### 검증 결과
2026-11-08, 기준 커밋 b21d1c9 이후 구현.
- `flutter analyze` 이슈 없음. `flutter test` 272개 통과(`test/first_minute_rewards_test.dart` 12개: runXp, 보너스 1회, 판 도중 Lv2 멱등, 판 끝 이중 계산/재알림 없음,
  Lv3 이상은 판 끝 알림, JSON 왕복, stickersSeen이 레벨보다 높은 기존 저장, 새 플레이어 대본 첫 판(연습 머지 → 6번째 배치에서 Lv2, 다시 로드, 재시작 정산),
  마지막 수의 레벨업, 기념 토스트, 기존 플레이어 흐름). `test/first_run_resume_test.dart`의 다시 로드 테스트는 환영 보너스를 반영하도록 기대값만 고쳤다.
  `flutter test --platform chrome test/web`(헤드리스 Chrome `--mute-audio`) 22개 통과.
- `tool/build_gamepix.sh`, `tool/build_crazygames.sh` 자체 검사 통과, Pages 빌드 성공. harness audit: Critical 0(기존 경고 7건).
- 독립 리뷰(code-reviewer): Critical/High 없음. Medium 3건을 고쳤다: 판 끝 알림 기준을 `stickerLevel`로 좁혀 stickersSeen이 레벨보다 높은 기존 저장의 알림을 유지,
  feature-camp-stickers 명세와 `stickers.dart` 주석의 보유 규칙 갱신, 약한 테스트 보강(HUD 실시간 Lv2와 XP, 재시작 시 재알림/효과음 없음, 마지막 수 레벨업).
  Low: 판 끝(배치 0) 정산에서도 `welcomeRun`을 끄고 불필요한 분기를 정리했다. 연쇄 기념 토스트와 다시 로드 뒤 기념 건너뛰기는 위젯 테스트가 없다.
- 보드 페인트 경로(`BoardStickerPainter`, 타일 그림)는 바꾸지 않았다. 판 도중 스티커가 하나 붙을 때 스티커 층 캐시가 한 번 다시 만들어질 뿐이라 모바일 프레임 시간은 다시 재지 않았다.
- 측정하지 못한 것: 실제 첫 판에서 Lv2까지 걸리는 시간(설계상 6번째 배치, 약 30~60초로 추정), 실기기.
