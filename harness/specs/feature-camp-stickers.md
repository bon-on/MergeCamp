---
id: feature-camp-stickers
title: MergeCamp 레벨업 보상 스티커와 보드 주변 꾸미기
status: active
owner: games
related_adrs:
  - adr-merge-camp-flutter-foundation
  - adr-merge-camp-crazygames-web
related_contracts:
  - contract-merge-camp-mvp
  - contract-merge-camp-crazygames
required_evidence:
  - flutter-analyze
  - flutter-tests
  - web-build
  - crazygames-web-build
  - harness-audit
---

# 기능 명세: 레벨업 보상 스티커와 보드 주변 꾸미기

## Problem
캠프 레벨이 올라도 눈에 보이는 변화는 테마 해금(Lv3, 6, 10)뿐이다. 도감(8단계)도 열리는 속도가 느리다. 판이 끝난 뒤
"내 캠프가 나만의 모습으로 바뀐다"는 보상이 없어 다음 판을 할 이유가 약하고, 플레이타임이 짧다(CrazyGames 런칭 평균 약 3분).
캠프 모양과 규칙은 바꾸지 않고, 레벨업마다 스티커를 받아 보드 주변에 붙이는 꾸미기를 추가한다.

## Scope
1. 스티커 카탈로그: 25종, 고정 순서. 레벨 L(1 ≤ L ≤ 25)을 처음 달성하면 카탈로그의 L번째 스티커를 갖는다.
   보유 여부는 `level`에서 계산하므로 별도 보유 목록을 저장하지 않는다(feature-first-minute-rewards 이후에는 `stickerLevel` = max(level, min(stickersSeen, 2))에서 계산한다. 환영 판의 판 도중 Lv2 때문이다). 기존 플레이어는 현재 레벨까지의 스티커를 즉시 갖는다.
   26레벨 이상은 새 스티커가 없다(레벨업 배너는 그대로).
   | Lv | 스티커 | Lv | 스티커 | Lv | 스티커 |
   |---|---|---|---|---|---|
   | 1 | Pennant | 10 | Moon (rare) | 19 | Butterfly |
   | 2 | Pine Tree | 11 | Binoculars | 20 | Rainbow (rare) |
   | 3 | Acorn | 12 | Kite | 21 | Bear Cub |
   | 4 | Lantern | 13 | Mushroom | 22 | Snowflake |
   | 5 | Spark (rare) | 14 | Fox | 23 | Leaf |
   | 6 | Marshmallow | 15 | Owl (rare) | 24 | Sunflower |
   | 7 | Compass | 16 | Map | 25 | Star Badge (rare) |
   | 8 | Mug | 17 | Canoe | | |
   | 9 | Hiking Boot | 18 | Fish | | |
2. 스티커 그림: 외부 에셋 없이 `CustomPainter` 벡터로 그린다. 한 스티커는 둥근 배지 모양(흰 테두리 + 그림자)이고 일반/희귀
   (rare)는 테두리 색으로 구분한다. 희귀의 반짝임 애니메이션은 꾸미기 화면과 보상 배너에서만 돌리고, 보드 주변에는 정적이다.
3. 슬롯: 보드 주변에 고정 슬롯 16개(위 5, 아래 5, 왼쪽 3, 오른쪽 3). 번호는 0-4 위(왼쪽→오른쪽), 5-9 아래(왼쪽→오른쪽),
   10-12 왼쪽, 13-15 오른쪽(위→아래)이다. 스티커는 보드 칸 위를 덮지 않고 보드 틀 바깥 여백에 놓인다.
   스티커 지름은 레인 폭의 0.86배이고 레인 폭과 보드 크기 계산은 10슬롯 때와 같다. 위/아래 줄 슬롯 중심은 보드 폭의
   0.08, 0.29, 0.5, 0.71, 0.92, 좌우 슬롯 중심은 보드 높이의 0.2, 0.5, 0.8이다(이웃 간격 0.21보드라 보드가 레인 약 4.1배 이상이면 겹치지 않는다).
   높이가 낮은 창에서 보드가 레인의 4.1배보다 작으면 레인(과 스티커)을 보드 × 0.21 / 0.86으로 줄인다(`StickerSlotGeometry.fitLane`). 보드 크기는 그대로다.
   스티커는 한 번에 한 슬롯에만 붙고, 한 슬롯에는 하나만 붙는다. 좁은 세로 화면에서 좌우 여백이 부족하면 위/아래 10개 슬롯만
   보드 옆에 그리고, 좌우 6개를 차지한 스티커는 저장 데이터에 남은 채 꾸미기 화면에서만 보인다.
   (2026-11-08 변경: 10슬롯 → 16슬롯. 카탈로그는 25종 그대로.)
4. 보상 흐름
   - 레벨이 오르면 새 스티커를 비어 있는 첫 슬롯(번호 순서: 위 줄 왼쪽부터, 그다음 아래 줄, 왼쪽, 오른쪽)에 자동으로 붙이고(빈 슬롯이 없으면 보관함에 둔다), 결과 요약과 레벨업 배너에
     "New sticker: <이름>"을 보여준다.
   - 처음 접속한 기존 플레이어에게는 보상 연출 없이 "N stickers ready to place" 한 줄만 한 번 보여준다. 이미 저장된 레벨에 해당하는
     스티커는 자동 배치하지 않고 보관함에 둔다(저장된 `stickersSeen`이 없으면 이 경우).
   - 처음 시작하는 플레이어(저장된 진행도가 없거나 `stickersSeen`이 없고 XP와 최고 점수가 0)는 Lv1 Pennant를 첫 빈 슬롯에 바로
     붙이고 `stickersSeen`을 현재 레벨로 저장한다. 안내나 보상 연출은 없고, 첫 판부터 보드 옆에 스티커가 하나 보인다.
   - 저장된 `stickersSeen`이 현재 레벨보다 높으면(다른 기기 등) 낮추지 않는다.
5. 꾸미기 화면(오버레이)
   - 보드 모양의 틀, 슬롯 16개, 보관함(보유한 스티커 그리드, 미보유는 실루엣과 필요한 레벨)을 보여준다.
   - 스티커를 탭해 고른 뒤 슬롯을 탭하면 붙고, 이미 차지한 슬롯이면 서로 바꾼다. 붙은 스티커를 다시 탭하면 보관함으로 돌아간다.
   - 진입점: HUD의 Decorate 버튼, 결과 요약의 Decorate 버튼. Esc/닫기 버튼으로 닫는다. 열려 있는 동안 보드 입력은 막힌다.
   - 키보드: 방향키/Tab으로 이동, Enter/Space로 선택. 닫으면 보드로 포커스가 돌아온다. 틀과 보관함은 별도 포커스 그룹이라
     Tab은 슬롯 16개를 읽는 순서(위 줄, 좌/우 쌍 세 줄, 아래 줄)로 끊김 없이 돈다. 방향키는 보관함과 틀 사이를 오간다.
   - 틀의 레인은 틀 크기의 0.15배(위/아래 다섯 슬롯이 겹치지 않는 폭)이고, 슬롯 탭 영역은 스티커보다 넓게 이웃 간격까지(약 47px) 잡는다.
6. 저장
   - `camp_progress_v1`(JSON)에 `stickerSlots`(슬롯 번호 문자열 → 스티커 id)와 `stickersSeen`(알림을 이미 보여준 최고 레벨)을 추가한다.
   - 슬롯 번호 체계는 `stickerSlotsVersion`(현재 2)으로 표시하고 항상 함께 쓴다. 이 값이 없거나 1이면 10슬롯 체계(0-2 위, 3-5 아래,
     6-7 왼쪽, 8-9 오른쪽)로 읽고 같은 면의 슬롯으로 옮긴다: 0→1, 1→2, 2→3(위 가운데 셋), 3→6, 4→7, 5→8(아래 가운데 셋),
     6→10, 7→12(왼쪽 위/아래), 8→13, 9→15(오른쪽 위/아래). 대응은 일대일이고 증가하므로 중복 처리(낮은 번호 우선)도 그대로다.
     그 밖의 값(2, 미래 버전, 손상된 값)은 현재 체계로 읽는다. 옮긴 배치는 다음 저장에서 버전 2로 기록되어 다시 옮겨지지 않는다.
   - 알려진 한계(하위 호환 아님): 16슬롯 저장을 이전 빌드가 읽으면(예: 클라우드 저장을 공유하는 오래 열린 탭) 0-9를 10슬롯
     체계로 해석하고 10-15는 버린다. 그 빌드가 다시 쓰면 버전 표시가 빠져 다음 로드에서 10슬롯 체계로 옮겨지므로, 3-9에 있던
     스티커는 다른 면으로 옮겨질 수 있고(3-4 위→6-7 아래, 6-7 아래→10/12 왼쪽, 8-9 아래→13/15 오른쪽) 10-15에 있던 스티커는
     보관함으로 돌아간다. 보유는 레벨에서 계산되므로 스티커를 잃지는 않는다. 오래 열린 탭은 시작 때 읽은 자기 형식으로 쓰므로
     해당하지 않고, 버전 2 저장 뒤에 이전 번들이 새로 시작될 때(캐시된 오래된 번들 등)만 생기는 드문 외형 문제로 받아들인다.
   - 파서는 관대하다: 보유하지 않은 스티커, 범위 밖 슬롯, 같은 스티커의 중복은 무시하고, 나머지는 살린다. 필드가 없으면 빈 배치다.
   - CrazyGames 계정 저장(Data 모듈)에 자동으로 포함된다. 데이터는 1 KB 미만이다.
7. 성능: 보드 주변 스티커 층은 정적 그림 캐시(`art_raster_cache`)에 키(배치, 논리 크기, DPR)로 한 장으로 담아 매 프레임 다시 그리지 않는다.
   배치가 바뀔 때만 캐시를 새로 만든다. 모바일 프레임 시간(feature-mobile-perf)을 악화시키지 않는다.

## Acceptance Criteria
- 카탈로그는 25종이고 id가 고유하며, 레벨 L의 스티커는 카탈로그 L번째다. rare는 Lv5, 10, 15, 20, 25뿐이다.
- 레벨 L인 진행도의 보유 스티커는 정확히 min(L, 25)개다(환영 판에서 판 도중 Lv2가 된 Lv1 진행도는 2개, feature-first-minute-rewards).
- 슬롯은 16개(위 5, 아래 5, 왼쪽 3, 오른쪽 3)이고 번호 0-4/5-9/10-12/13-15가 각각 위/아래/왼쪽/오른쪽이다.
- 런이 끝나 레벨이 오르면 새 스티커가 첫 빈 슬롯에 붙고 `RunOutcome`으로 알 수 있다. 한 번에 여러 레벨이 오르면 각각 순서대로 붙는다.
  빈 슬롯이 없으면 붙지 않고 보관함에 남는다.
- 배치는 JSON 왕복 후 같다. 보유하지 않은 스티커, 범위 밖 슬롯, 중복 스티커는 파싱에서 버려진다. 손상된 값은 빈 배치로 대체되고 플레이를 막지 않는다.
- `stickerSlotsVersion`이 없는(또는 1인) 10슬롯 저장은 각 스티커가 같은 면(위/아래/왼쪽/오른쪽)의 슬롯으로 옮겨지고, 중복이나 손실이 없으며,
  옮긴 뒤 JSON 왕복에서 다시 옮겨지지 않는다. 10슬롯 체계의 범위 밖 번호(10 이상)와 손상된 값은 기존 규칙대로 버려진다.
- 꾸미기 화면에서 붙이기, 바꾸기, 떼기가 되고, 같은 스티커가 두 슬롯에 있을 수 없다. 슬롯 16개가 모두 틀 안에 겹치지 않게 보이고 Tab 순서가 읽는 순서다.
- `stickersSeen`이 없는 기존 진행도에서는 보상 연출 없이 안내 한 줄만 보이고, 스티커는 자동 배치되지 않는다.
- 처음 시작하는 플레이어는 첫 로드 직후 Pennant가 슬롯 0에 붙어 있고 `stickersSeen`이 1이며, JSON 왕복 뒤에도 같다. 다시 로드해도 또 붙이지 않는다.
- 꾸미기 화면이 열려 있는 동안 보드 입력이 막히고, 닫으면 입력이 다시 된다. Esc로 닫힌다.
- 1280x720, 1366x768, 390x844에서 오버플로 없이 표시된다. 스티커가 보드 칸을 덮지 않고 서로 겹치지 않는다. 넓은 화면은 16개, 좁은 세로 화면은 위/아래 10개를 그린다.
- 스티커 층은 정적이며 캐시된다(배치가 같으면 재생성하지 않는다). 기존 성능 테스트와 모든 기존 테스트가 통과한다.
- lib/ 문자열은 영어 ASCII다. CrazyGames/GamePix 빌드 자체 검사가 통과한다.

## Constraints
- 새 패키지 의존성을 추가하지 않는다. 그림은 코드로 그린다.
- 머지 규칙, 점수, XP, 레벨 곡선은 바꾸지 않는다. 스티커는 꾸미기 전용이며 게임 규칙에 영향을 주지 않는다.
- 판 도중 스냅샷(`activeRun`, adr-run-snapshot)의 형식은 바꾸지 않는다.
- 광고, 결제, 외부 요청을 추가하지 않는다.

## Follow-ups (이 명세 밖)
- 결과 카드와 공유(스티커로 꾸민 캠프 이미지 포함), 보상형 이어하기, 선택형 보상 상자, 자유 배치.

## Evidence
- `flutter analyze`, `flutter test`, `flutter test --platform chrome test/web`
- `tool/build_crazygames.sh`, `tool/build_gamepix.sh`
- `node <harness-lab>/dist/index.js audit . --format md`

### 검증 결과
2026-11-07, 기준 커밋 ae97828 이후 구현.
- `flutter analyze` 이슈 없음. `flutter test` 226개 통과(Pennant 후속 변경 후 227개)(`test/meta_stickers_test.dart`, `test/decor_stickers_test.dart` 포함). `flutter test --platform chrome test/web` 16개 통과.
- `tool/build_crazygames.sh`, `tool/build_gamepix.sh` 자체 검사 통과. `flutter build web --release --base-href /MergeCamp/` 성공.
- harness audit: Critical 0. 남은 경고는 이 명세와 무관한 기존 항목(workflow/maintenance 파일, how-to-play 백링크)이다.
- 독립 리뷰(code-reviewer): Critical/High 없음. 320x640 꾸미기 헤더 오버플로는 수정했고, 레이아웃 테스트의 9개 크기를 모두 꾸미기 테스트에 넣었다.
- 알려진 한계: 보드 틀이 물리 픽셀 320만을 넘는 큰 데스크톱 창(예: 1920x1080, DPR 2)에서는 스티커 층을 캐시하지 않고 벡터로 그린다(배경 레이어와 같은 한도). 스티커 레인 때문에 높이가 제한된 가로 화면에서는 보드가 레인 두 개만큼 작아진다(1280x720에서 약 620 → 561px).
- 측정하지 못한 것: 모바일 프레임 시간 재측정, 실기기(Android Chrome, iPhone Safari).

### 검증 결과: 16슬롯 (2026-11-08, 기준 커밋 3816041 이후)
- 요구사항 → 검사 대응
  - 16슬롯 배치/면 구분, 이동 순서: `test/meta_stickers_test.dart` "the new layout has 5 above, 5 below, 3 left and 3 right"
  - 10슬롯 저장 이전(면 유지, 중복/손실 없음, 다음 빈 칸 0): "a full ten-slot save keeps every sticker on its side"
  - 이전 후 왕복 안정성: "a migrated save round trips without moving again", 새 저장: "new saves load every slot as is, sides included"
  - 버전 표시 해석과 관대한 파싱: "layout version 1 or none migrates, anything else is current", "legacy parsing tolerates bad data like the current one"
  - 모든 슬롯이 찼을 때 보관함: "with every slot taken a new sticker stays in the tray"(Lv16, 16슬롯)
  - 11개 화면 크기(기존 9개 + 낮은 창 560x560, 600x500)에서 보드 스티커 16/10개, 서로/보드와 겹침 없음, 꾸미기 슬롯 16개 틀 안·겹침 없음: `test/decor_stickers_test.dart` "stickers and decor screen fit ..."
  - Tab 순서와 방향키 이동: "Tab walks the decor slots in reading order at ..."(1280x720, 390x844)
  - 캐시: "the board sticker layer is cached per placement"
- `flutter analyze` 이슈 없음, `flutter test` 282개 통과, `flutter test --platform chrome test/web` 22개 통과,
  `tool/build_crazygames.sh`, `tool/build_gamepix.sh` 자체 검사 통과.
- 보드 크기(위젯 테스트, DPR 1, 보드 한 변 / 레인 / 그리는 스티커 수): 1280x720 560.8 / 43.2 / 10→16, 1366x768 629.8 / 46.1 / 10→16,
  390x844 366.0 / 36.6 / 6→10(좌우 숨김). 보드와 레인 크기는 변경 전과 같다.
  꾸미기 틀(318.7 / 326.0px)의 스티커 지름은 46.6→41.1, 47.7→42.1px로 작아졌고 탭 영역은 46.9 / 47.9px다.
- 평상시 프레임 비용: feature-mobile-perf 방식을 따른 스크래치 하네스(헤드리스 Chrome, 390x844 DPR 3 터치, CPU 4배 감속, SDK 차단,
  Lv16 진행도에 16슬롯을 채워 시드, 이어하기 판 없이 새 판 대기 화면)로 기준 3816041과 HEAD를 번갈아 8회씩 2초 측정했다.
  p50 중앙값 기준 9.1ms, HEAD 6.8ms(p95 중앙값 11.6 / 9.6ms). 실행 간 흔들림(3.7~12.7ms)이 커서 개선이 아니라 악화 없음으로만 읽는다.
  머지/연쇄 구간과 실기기는 재측정하지 않았다.
- 독립 리뷰(code-reviewer): Critical/High 없음. Medium(높이가 낮은 좁은 창, 예: 560x560에서 보드가 레인 4.1배 미만이라 스티커가 서로 겹침)은
  레인 상한(`fitLane`)으로 고치고 두 크기를 테스트에 넣었다(수정 전 실패 확인). Low(하위 호환 한계 설명이 실제보다 가벼움)는 위 문구를 고쳤다.
