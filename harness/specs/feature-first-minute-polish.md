---
id: feature-first-minute-polish
title: MergeCamp 첫 1분 다듬기(연습 머지 뒤 다음 행동 안내, 초반 타일 미리 그리기)
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
  - crazygames-web-build
  - harness-audit
---

# 기능 명세: 첫 1분 다듬기

## Problem
CrazyGames 데스크톱 전환율(1분 이상 플레이)이 48.25%로 2점 기준 50%에 못 미친다(2026-11-17, 기간 11/10~11/16).
직접 따라가 본 첫 실행에서 연습 머지가 끝나면 보드에 타일 하나만 남고 다음에 무엇을 할지 보이는 안내가 없다.
또 실기기 모바일 테스트에서 "초기 로딩이 느리고, 초반 캠프가 합쳐질 때 렉이 있으며 계속하면 빨라진다"는 보고가 있었다.
후자는 래스터 캐시(feature-mobile-perf)가 처음 쓰는 타일마다 한 번씩 채워지고 새 그림을 처음 그릴 때 셰이더가 컴파일되는 것과 맞는다(추정, 실기기 미측정).

## Scope
1. 다음 행동 안내
   - 연습 머지(`guidedPractice`가 끝나는 배치) 직후 보드 아래 줄 위에 한 줄 안내를 띄운다:
     "Nice! Keep placing tiles - 3 touching matches merge."
   - 연습 중에는 기존 "Tap the glowing plot to merge!" 줄이 그대로이고 안내는 없다. 연습을 건너뛰거나 다시 불러온 판에서는 안내가 없다.
   - 판의 배치가 3을 넘으면(4번째 배치), 판이 끝나면, 재시작하면 사라진다. 저장하지 않는다.
   - 버튼이 없는 안내 줄은 탭을 통과시켜 맨 아래 줄 칸을 누를 수 있다.
2. 초반 타일 미리 그리기(웹 전용, `ArtRasterCache.enabled`일 때만)
   - 보드가 나타난 뒤 티어 1~5 타일(보드 칸 크기, 애니메이션 켠/끈 두 가지, 배지 없는 미리보기 크기)을 거의 보이지 않게(opacity 0.01)
     120ms 간격으로 한 티어씩 그리고 끝나면 스스로 사라진다. 실제 타일 위젯이므로 캐시 키가 실제 사용과 같다.
   - 네이티브와 VM 테스트(캐시 꺼짐)에서는 아무것도 하지 않는다.
3. 초기 로딩: 측정해 보니 `canvaskit.wasm`이 `main.dart.js`보다 먼저 병렬로 요청되고 있어 사전 로드 추가는 하지 않는다. 변경 없음.

## Acceptance Criteria
- 새 플레이어가 연습 머지를 마치면 안내 줄이 보이고 "Skip practice"는 없다. 배치 3까지 유지되고 4번째 배치에서 사라진다.
- 연습을 건너뛴 판에서는 안내가 뜨지 않는다.
- 안내 줄이 떠 있어도 맨 아래 줄 칸 탭이 배치된다.
- TileWarmup은 캐시가 켜져 있을 때 120ms마다 한 티어(3개 위젯)씩 올리고 끝나면 0개가 되며, 캐시가 꺼져 있으면 아무것도 그리지 않는다.
- 규칙, 점수, XP, 저장 형식, 효과음, 광고 흐름은 바뀌지 않는다. lib/ 문자열은 영어 ASCII다.

## Constraints
- 새 패키지, 새 에셋 없음. 안내는 저장하지 않는다.

## Plan and check mapping
| Requirement | Files | Verification |
|---|---|---|
| 안내 줄 | `lib/src/game/ui/camp_layout.dart`, `lib/src/game/merge_camp_screen.dart` | `test/first_minute_polish_test.dart` |
| 미리 그리기 | `lib/src/art/tile_warmup.dart`, `lib/src/game/ui/board_view.dart` | `test/first_minute_polish_test.dart` (TileWarmup) |

## Evidence
- `flutter analyze`, `flutter test`, `flutter test --platform chrome test/web`, `tool/build_crazygames.sh`
- 실기기 효과는 측정하지 못했다. 업로드 뒤 CrazyGames 전환율과 실기기 체감으로 확인한다.
