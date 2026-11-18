---
id: feature-camp-shift
title: MergeCamp 캠프 이동 도구(Shift) - 모든 캠프를 한 방향으로 밀기
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
  - harness-audit
---

# 기능 명세: 캠프 이동 도구(Shift)

## Problem
지금은 도구가 Trail Axe(타일 하나 삭제)뿐이라 보드가 어긋나게 찼을 때 되돌릴 방법이 없다.
캠프를 위/아래/왼쪽/오른쪽으로 옮겨 3개씩 맞붙이는 강한 도구를 추가한다.
강한 만큼 흔하게 얻을 수 없도록, 한 번에 많은 캠프를 합치거나 특정 미션을 완료했을 때만 받는다.

## Scope
1. 규칙(컨트롤러)
   - Shift 충전은 0~1개(`maxShifts = 1`)이고 판 시작은 0개다. 판이 끝나면 사라지고 다음 판으로 넘어가지 않는다.
   - 얻는 방법
     - 한 번의 배치에서 한 번에 5칸 이상이 합쳐지거나(`bigShiftCluster = 5`), 그 배치의 연쇄가 3 이상이면(`chainForShift = 3`) 1개를 자동으로 받는다.
     - "Merge N+ tiles at once" 미션을 완료하면 Trail Axe 대신 Shift 1개를 받는다. Shift가 이미 1개면 Trail Axe, 그것도 상한이면 +150점(기존 규칙)으로 넘어간다.
   - 쓰는 방법: 방향(위/아래/왼쪽/오른쪽)을 고르면 모든 캠프가 그 벽쪽으로 막힐 때까지 미끄러진다. 순서는 바뀌지 않고, 이동 중 서로 겹치거나 건너뛰지 않는다.
     - 움직일 캠프가 하나도 없으면 아무 일도 일어나지 않고 충전도 쓰지 않는다(`blocked`).
     - 이동이 끝난 뒤 맞닿은 같은 티어 3개 이상 묶음은 모두 합쳐진다. 합쳐지는 기준 칸은 묶음에서 그 방향의 벽에 가장 가까운 칸(같으면 낮은 칸 번호)이고, 합친 뒤 연쇄도 이어진다.
     - 점수, 최고 티어, 합친 횟수, 최장 연쇄, 미션 진행은 배치로 합쳐질 때와 같은 규칙으로 센다.
     - 배치 횟수, 티어 상한, Trail Axe 지급 시계, 새 타일 뽑기(일일 캠프의 같은 순서)에는 영향이 없다. 새 타일은 뽑지 않는다.
   - 쓸 수 없는 때: 게임 오버, 연습(guided practice) 중. 가득 찬 보드는 움직일 곳이 없어 `blocked`이므로 Shift로 막힌 판을 살릴 수 없다(막힌 판은 Trail Axe만 살린다).
   - 진행 중 판 저장(`adr-run-snapshot`)에 `shifts`(0~1)를 더한다. 없으면 0이다. 첫 배치 전(`placements == 0`)에는 0이어야 한다.
2. 화면
   - 도구 영역에 Shift 버튼을 Trail Axe 옆(넓은 화면은 아래)에 둔다. 충전이 없으면 흐리게 보이고, 도움말(tooltip)에 얻는 방법을 적는다.
   - 누르면 보드 아래 줄에 방향 화살표 4개와 취소 버튼이 뜬다. 화살표를 누르면 실행하고 모드가 끝난다. Trail Axe 모드와 동시에 켜지 않는다.
   - 키보드: `C`로 Shift 모드를 켜고 끄며, 모드에서 방향키/WASD가 방향을 정하고 `Esc`가 취소한다.
   - 이동 연출: 움직인 캠프가 도착 칸까지 약 160ms 미끄러지고, 그 뒤 합쳐진 묶음마다 기존 흡수/팝업/파티클을 재생한다. 연출은 입력을 막지 않는다.
   - 얻을 때 토스트("Shift earned! Slide every camp one way."), 미션 보상 토스트는 "+1 Shift". How to play 3번째 문구에 한 줄 추가한다.
3. 제외: 새 타일 뽑기 변경, 스코어 규칙 변경, 다중 충전, 광고 보상으로 얻기, 결과/공유 카드 변경.

## Acceptance Criteria
- 컨트롤러 단위 테스트: 슬라이드 4방향(빈 칸 메우기, 순서 유지), 움직일 게 없으면 충전이 그대로, 5칸 합치기/3연쇄 배치가 충전을 주고 상한 1을 넘지 않는다, 미션 보상이 Shift를 먼저 준다.
- 이동 뒤 합치기: 기준 칸이 벽쪽 칸이고 점수/합친 횟수/최장 연쇄/최고 티어가 반영된다. 배치 횟수와 새 타일 미리보기(큐)는 바뀌지 않는다.
- 저장/복원: `shifts`가 왕복하고, 없는 예전 저장은 0으로, 범위를 벗어나거나 `placements == 0`에서 1이면 거부한다.
- 화면 테스트: 버튼 활성/비활성, 모드 진입, 화살표로 실행, 취소, Trail Axe 모드와 배타, 연습 중 불가, 키보드(C, 방향키, Esc), 작은 화면(320x640, 360x640, 640x480)에서 오버플로 없음.
- 기존 테스트, 웹 빌드, CrazyGames/GamePix 번들 자체 점검이 통과한다.

## Constraints
- 새 의존성 없음. lib 문자열은 영어 ASCII. 머지 규칙과 난이도 상승은 결정적이고 테스트 가능해야 한다(`constraints.md`).
- Shift 연출은 `BoardFx` 큐를 그대로 쓰고 새 캐시 키를 만들지 않는다.

## Evidence
- `flutter analyze`, `flutter test`, `flutter test --platform chrome test/web`
- `tool/build_crazygames.sh`, `tool/build_gamepix.sh`
- `node <harness-lab>/dist/index.js audit . --format md`
