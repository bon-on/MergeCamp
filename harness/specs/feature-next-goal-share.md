---
id: feature-next-goal-share
title: MergeCamp 결과 요약의 다음 목표와 공유용 결과 카드
status: active
owner: games
related_adrs:
  - adr-merge-camp-flutter-foundation
  - adr-merge-camp-crazygames-web
  - adr-merge-camp-gamepix-web
related_contracts:
  - contract-merge-camp-mvp
  - contract-merge-camp-crazygames
  - contract-merge-camp-gamepix
required_evidence:
  - flutter-analyze
  - flutter-tests
  - web-build
  - crazygames-web-build
  - gamepix-web-build
  - harness-audit
---

# 기능 명세: 결과 요약의 다음 목표와 공유용 결과 카드

## Problem
CrazyGames Basic Launch 지표가 낮다: 평균 플레이 3분, 1분 이상 플레이 33%, D1 리텐션 2.7%.
판이 끝난 요약 화면은 점수와 XP 진행 바만 보여 주고 "다음에 무엇을 얻는지"가 숫자로 보이지 않는다. 결과를 남에게 보여 줄 방법도 없다.
판마다 가장 가까운 다음 목표를 숫자로 보여 주고, 결과를 이미지/텍스트로 공유할 수 있게 한다.

## Scope
1. 다음 목표(Next goal) 블록
   - 순수 함수 `nextGoals(CampProgress)`가 적용된 진행도에서 후보를 만든다(`lib/src/meta/next_goal.dart`).
     - 레벨: 다음 레벨까지 모자란 XP와 그 레벨의 스티커 이름(25레벨 이후에는 스티커 없이 레벨만). 다음 레벨에서 테마도 열리면 같은 목표에 함께 적는다.
     - 테마: 아직 잠긴 다음 테마까지 모자란 XP. 그 테마가 바로 다음 레벨에서 열리면 레벨 목표에 합치고 따로 만들지 않는다.
     - 도감: 아직 발견하지 않은 가장 낮은 캠프 단계(1~8)의 이름과 발견 수(N/8). 모두 발견했으면 없다.
   - 거리는 "예상 판 수"로 비교한다: XP 목표는 모자란 XP / 300(평균 판당 XP, `CampProgress` 튜닝 메모), 도감 목표는
     max(1, 목표 단계 - 그보다 낮은 발견 단계 중 최고). 가장 작은 하나를 강조하고, 같으면 레벨 > 도감 > 테마 순으로 고른다.
   - 요약에는 최대 3개를 거리 순으로 보여 준다. 강조 목표는 그림(스티커/캠프 타일/테마 아이콘), 제목, 숫자, 진행 바를 갖고,
     나머지는 한 줄씩 작게 보인다.
2. 버튼 배치
   - Play again을 가장 크게(높이 60, 굵은 큰 글씨) 두고, 요약 내용이 길어도 항상 보이도록 스크롤 영역 밖 아래쪽에 고정한다.
   - Album/Decorate와 공유 버튼은 그 아래 작은 보조 버튼이다.
3. 결과 카드(공유 이미지)
   - `Canvas`/`PictureRecorder`/`Picture.toImage`로 로컬에서 1080x1350 PNG를 그린다. 네트워크와 새 패키지는 쓰지 않는다.
   - 내용: 게임 이름(MergeCamp), 점수, 최고 점수, 신기록이면 "New best!", 최고 캠프 그림과 이름, 캠프 레벨,
     마지막 보드(4x4 타일)와 그 주변에 붙인 스티커의 축소판, 포털 이름/URL이 없는 꼬리말("Can you build a bigger camp?").
   - 카드는 버튼을 눌렀을 때 한 번 그리고 같은 요약 안에서는 재사용한다.
4. 공유 동작(요약의 보조 버튼, 모두 실패해도 예외 없이 짧은 토스트)
   - Copy result: "I scored N in MergeCamp! Top camp: X, camp Lv L. <링크>" 텍스트를 클립보드에 넣는다. 성공 "Copied!", 실패 "Could not copy".
     Flutter `Clipboard`가 실패하면 웹에서는 숨긴 textarea + `execCommand('copy')`로 한 번 더 시도한다.
   - Save card: 웹에서만 보인다. PNG를 Blob URL과 `<a download>` 클릭으로 내려받는다. 성공 "Card saved", 실패 "Could not save".
   - Share: 웹에서 `navigator.share`가 있고 권한 정책이 web-share를 막지 않을 때만 보인다. 텍스트와 링크를 보내고,
     `navigator.canShare({files})`가 참이면 PNG 파일도 붙인다. 사용자가 취소하면(AbortError) 토스트 없이 끝나고, 그 밖의 실패는 "Could not share".
   - 웹 연동은 기존 방식대로 `dart:js_interop` 확장 타입과 `dart.library.js_interop` 조건부 import로 한다(`package:web` 없음).
5. 빌드별 링크와 노출(`GamePlatform.shareLink`)
   - CrazyGames 빌드(`CRAZYGAMES=true`): `https://www.crazygames.com/game/mergecamp-jvc`. 상수는 CrazyGames 어댑터 안에 두어 다른 빌드에서는 트리 셰이킹된다.
   - GitHub Pages(플래그 없음)와 모바일: `https://bon-on.github.io/MergeCamp/`.
   - GamePix 빌드(`GAMEPIX=true`): `null`. 공유 UI가 전혀 없고 외부 링크 문자열도 없다. `main.dart.js`에 CrazyGames 문자열이 없어야 한다.
   - 링크는 공유 텍스트 안의 글자일 뿐이며, 게임이 링크를 열거나 다른 페이지로 이동하지 않는다.
6. 공유는 광고, `gameplayStart/Stop`, 입력 차단 상태에 영향을 주지 않는다(요약이 떠 있는 동안 gameplay는 이미 멈춰 있다).

## Acceptance Criteria
- `nextGoals`: 레벨 목표의 모자란 XP는 `xpForNextLevel - xpIntoLevel`이고 스티커 이름은 `Sticker.forLevel(level + 1)`이다.
  다음 레벨에서 열리는 테마는 레벨 목표에 합쳐지고, 더 먼 테마는 따로 나온다. 도감 목표는 가장 낮은 미발견 단계다.
  강조는 예상 판 수가 가장 작은 하나이며 동점 규칙이 결정적이다. 25레벨 이상, 모든 테마/도감 완료에서도 예외 없이 동작한다.
- 요약에 Next goal 블록과 숫자가 보이고, Play again이 가장 큰 버튼이며 스크롤하지 않아도 화면 안에 있다.
- 1280x720, 1280x672, 1366x768, 390x844, 390x796, 844x390, 360x640, 640x480, 320x640에서 요약이 오버플로 없이 표시된다.
- 결과 카드 렌더러가 PNG 시그니처를 가진 비어 있지 않은 바이트를 만든다(인코더 주입 가능).
- GamePix 플랫폼(`shareLink == null`)에서는 Copy/Save/Share 버튼이 없다. Pages/CrazyGames 링크가 공유 텍스트에 들어간다.
- 클립보드/저장/공유가 예외를 던지거나 실패해도 앱이 멈추지 않고 짧은 토스트만 보인다. 공유 중 플랫폼 이벤트(gameplay, 광고)가 호출되지 않는다.
- `tool/build_gamepix.sh` 자체 검사가 통과하고, GamePix `main.dart.js`에 `crazygames`, `bon-on.github.io` 문자열이 없다.
- lib/ 문자열은 영어 ASCII다. 기존 테스트가 모두 통과한다.

## Constraints
- 새 패키지 의존성 없음. 네트워크 요청 없음. 머지 규칙, 점수, XP, 레벨 곡선은 바꾸지 않는다.
- 보드 페인트 경로는 바꾸지 않는다(카드는 요약에서 요청할 때만 오프스크린으로 그린다).
- `activeRun` 스냅샷 형식(adr-run-snapshot)은 바꾸지 않는다.

## Decisions
- CrazyGames ADR의 "외부 링크 없음"은 플레이어를 포털 밖으로 보내는 링크/내비게이션을 뜻한다고 해석한다. 공유 텍스트에는 CrazyGames 자체 게임 페이지 URL만 넣고 게임은 그 URL을 열지 않는다(adr-merge-camp-crazygames-web에 기록).
- Save card/Share는 웹 전용이다. 모바일 앱은 Copy result만 보인다.

## Plan and check mapping
| Requirement | Files | Verification |
|---|---|---|
| Next goal selection | `lib/src/meta/next_goal.dart` | `test/next_goal_test.dart` |
| Summary block, button sizes, layouts, gating, toasts | `lib/src/game/ui/run_summary_overlay.dart`, `camp_ui.dart`, `merge_camp_screen.dart` | `test/result_share_test.dart` |
| Result card PNG | `lib/src/game/share/result_card.dart`, `camp_tile_art.dart` (paint hook) | `test/result_share_test.dart` |
| Web clipboard/download/share | `lib/src/game/share/result_share*.dart` | `test/web/result_share_web_test.dart`, 수동 확인 없음 |
| Flavor links | `game_platform.dart`, `crazygames_platform.dart` | `test/result_share_test.dart`, `tool/build_gamepix.sh` grep |

## Evidence
- `flutter analyze`, `flutter test`, `flutter test --platform chrome test/web`
- `tool/build_crazygames.sh`, `tool/build_gamepix.sh`
- `node <harness-lab>/dist/index.js audit . --format md`
