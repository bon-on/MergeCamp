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
   보유 여부는 `level`에서 계산하므로 별도 보유 목록을 저장하지 않는다. 기존 플레이어는 현재 레벨까지의 스티커를 즉시 갖는다.
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
3. 슬롯: 보드 주변에 고정 슬롯 10개(위 3, 아래 3, 왼쪽 2, 오른쪽 2). 스티커는 보드 칸 위를 덮지 않고 보드 틀 바깥 여백에 놓인다.
   스티커는 한 번에 한 슬롯에만 붙고, 한 슬롯에는 하나만 붙는다. 좁은 세로 화면에서 좌우 여백이 부족하면 위/아래 6개 슬롯만
   보드 옆에 그리고, 나머지 4개를 차지한 스티커는 꾸미기 화면에서만 보인다.
4. 보상 흐름
   - 레벨이 오르면 새 스티커를 비어 있는 첫 슬롯에 자동으로 붙이고(빈 슬롯이 없으면 보관함에 둔다), 결과 요약과 레벨업 배너에
     "New sticker: <이름>"을 보여준다.
   - 처음 접속한 기존 플레이어에게는 보상 연출 없이 "N stickers ready to place" 한 줄만 한 번 보여준다. 이미 저장된 레벨에 해당하는
     스티커는 자동 배치하지 않고 보관함에 둔다(저장된 `stickersSeen`이 없으면 이 경우).
5. 꾸미기 화면(오버레이)
   - 보드 모양의 틀, 슬롯 10개, 보관함(보유한 스티커 그리드, 미보유는 실루엣과 필요한 레벨)을 보여준다.
   - 스티커를 탭해 고른 뒤 슬롯을 탭하면 붙고, 이미 차지한 슬롯이면 서로 바꾼다. 붙은 스티커를 다시 탭하면 보관함으로 돌아간다.
   - 진입점: HUD의 Decorate 버튼, 결과 요약의 Decorate 버튼. Esc/닫기 버튼으로 닫는다. 열려 있는 동안 보드 입력은 막힌다.
   - 키보드: 방향키/Tab으로 이동, Enter/Space로 선택. 닫으면 보드로 포커스가 돌아온다.
6. 저장
   - `camp_progress_v1`(JSON)에 `stickerSlots`(슬롯 번호 문자열 → 스티커 id)와 `stickersSeen`(알림을 이미 보여준 최고 레벨)을 추가한다.
   - 파서는 관대하다: 보유하지 않은 스티커, 범위 밖 슬롯, 같은 스티커의 중복은 무시하고, 나머지는 살린다. 필드가 없으면 빈 배치다.
   - CrazyGames 계정 저장(Data 모듈)에 자동으로 포함된다. 데이터는 1 KB 미만이다.
7. 성능: 보드 주변 스티커 층은 정적 그림 캐시(`art_raster_cache`)에 키(배치, 논리 크기, DPR)로 한 장으로 담아 매 프레임 다시 그리지 않는다.
   배치가 바뀔 때만 캐시를 새로 만든다. 모바일 프레임 시간(feature-mobile-perf)을 악화시키지 않는다.

## Acceptance Criteria
- 카탈로그는 25종이고 id가 고유하며, 레벨 L의 스티커는 카탈로그 L번째다. rare는 Lv5, 10, 15, 20, 25뿐이다.
- 레벨 L인 진행도의 보유 스티커는 정확히 min(L, 25)개다.
- 런이 끝나 레벨이 오르면 새 스티커가 첫 빈 슬롯에 붙고 `RunOutcome`으로 알 수 있다. 한 번에 여러 레벨이 오르면 각각 순서대로 붙는다.
  빈 슬롯이 없으면 붙지 않고 보관함에 남는다.
- 배치는 JSON 왕복 후 같다. 보유하지 않은 스티커, 범위 밖 슬롯, 중복 스티커는 파싱에서 버려진다. 손상된 값은 빈 배치로 대체되고 플레이를 막지 않는다.
- 꾸미기 화면에서 붙이기, 바꾸기, 떼기가 되고, 같은 스티커가 두 슬롯에 있을 수 없다.
- `stickersSeen`이 없는 기존 진행도에서는 보상 연출 없이 안내 한 줄만 보인다.
- 꾸미기 화면이 열려 있는 동안 보드 입력이 막히고, 닫으면 입력이 다시 된다. Esc로 닫힌다.
- 1280x720, 1366x768, 390x844에서 오버플로 없이 표시된다. 스티커가 보드 칸을 덮지 않는다.
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
- `flutter analyze` 이슈 없음. `flutter test` 226개 통과(`test/meta_stickers_test.dart`, `test/decor_stickers_test.dart` 포함). `flutter test --platform chrome test/web` 16개 통과.
- `tool/build_crazygames.sh`, `tool/build_gamepix.sh` 자체 검사 통과. `flutter build web --release --base-href /MergeCamp/` 성공.
- harness audit: Critical 0. 남은 경고는 이 명세와 무관한 기존 항목(workflow/maintenance 파일, how-to-play 백링크)이다.
- 독립 리뷰(code-reviewer): Critical/High 없음. 320x640 꾸미기 헤더 오버플로는 수정했고, 레이아웃 테스트의 9개 크기를 모두 꾸미기 테스트에 넣었다.
- 알려진 한계: 보드 틀이 물리 픽셀 320만을 넘는 큰 데스크톱 창(예: 1920x1080, DPR 2)에서는 스티커 층을 캐시하지 않고 벡터로 그린다(배경 레이어와 같은 한도). 스티커 레인 때문에 높이가 제한된 가로 화면에서는 보드가 레인 두 개만큼 작아진다(1280x720에서 약 620 → 561px).
- 측정하지 못한 것: 모바일 프레임 시간 재측정, 실기기(Android Chrome, iPhone Safari).
