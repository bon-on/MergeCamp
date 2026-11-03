---
id: feature-retention-polish
title: MergeCamp 시각 개편, 머지 손맛, 재플레이 동기(미션, 도감, 캠프 레벨)
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
  - harness-audit
---

# 기능 명세: MergeCamp 시각 개편, 머지 손맛, 재플레이 동기

## Problem
CrazyGames가 MergeCamp를 "The overall quality of the game does not yet meet the expectations of our platform"으로 거절했다.
현재 타일은 "T1" 글자와 Material 아이콘뿐이라 시제품처럼 보이고, 머지 순간의 연출이 약하며, 배경음악이 없다.
최고 점수도 저장하지 않아 판이 끝나면 남는 것이 없고, 다시 플레이할 이유(목표, 수집, 성장)가 없다.

## Scope
1. 시각 개편
   - 8단계 캠프 타일을 외부 에셋 없이 `CustomPainter` 벡터 일러스트로 그린다(Trail Tent, Cook Fire, Supply Shed, Scout Cabin, Signal Tower, Base Lodge, Summit Camp, Star Observatory). 티어 번호는 작은 배지로만 보조 표시한다. Cook Fire 불꽃처럼 가벼운 루프 애니메이션은 허용하되 정적 모드(테스트, 접근성)를 지원한다.
   - 숲 배경(하늘, 언덕, 나무 실루엣)을 테마별로 그린다. 테마: Summer(기본), Autumn, Snow, Night.
   - 넓은 화면(가로가 충분한 데스크톱/16:9 iframe)에서는 보드를 가운데 크게 두고 좌우 패널에 미션, 캠프 레벨, 다음 타일, 도구, 최고 점수를 배치한다. 좁은 화면(모바일 세로)에서는 위아래로 쌓는다. 1280x720, 1366x768, 390x844에서 스크롤/오버플로가 없어야 한다.
2. 머지 손맛
   - 머지되는 타일들이 기준 칸으로 빨려 들어가고, 결과 타일이 튀어 오르며, 파티클과 "+점수" 팝업을 보여준다.
   - 연쇄 머지는 "Chain x2" 같은 배너와 더 높은 효과음으로 강조한다.
   - 새 타일 배치는 떨어져 앉는 짧은 애니메이션을 가진다.
   - 보드가 13칸 이상 차면 가장자리 위험 표시(맥동 비네트)를 보여준다.
   - 애니메이션은 입력을 막지 않는다(빠른 연속 입력에서도 규칙 처리는 즉시, 연출은 뒤따른다).
3. 판 안의 목표: 미션
   - 판마다 미션 3개를 제시한다(예: 타일 N개 배치, N연쇄 만들기, 특정 캠프 세우기, 한 번에 4개 이상 머지, 점수 N 달성). 달성하면 Trail Axe 1개(상한이면 점수 보너스)와 XP 보너스를 준다. 세 개를 모두 달성하면 다음 미션 세트가 열린다.
4. 판 사이의 동기: 결과 화면, 도감, 캠프 레벨
   - 게임 오버 요약: 점수, 최고 점수("New best!"), 최고 캠프, 최장 연쇄, 완료 미션, 획득 XP와 레벨 진행 바, 새로 해금된 테마, 바로 다시 하기 버튼.
   - 최고 점수를 저장하고 HUD에 표시한다.
   - 캠프 도감: 8단계를 그림으로 모은다. 미발견 단계는 실루엣과 "???"로 보인다. 처음 만든 단계는 비차단 "New camp discovered" 배너로 알리고 즉시 저장한다.
   - 캠프 레벨: 판의 점수(와 미션 보너스)가 XP로 누적된다. 레벨에 따라 테마가 열린다(Summer Lv1, Autumn Lv3, Snow Lv6, Night Lv10). 테마는 꾸미기 전용이며 규칙에 영향을 주지 않는다. 플레이어는 열린 테마를 고를 수 있다.
   - 진행도는 `shared_preferences` 키 `camp_progress_v1`(JSON)에 저장한다. 읽기/쓰기 실패나 손상된 값은 초기 진행도로 대체하고 플레이를 막지 않는다.
   - 판 도중 재시작(R, 재시작 버튼)도 그 판을 끝난 것으로 보고 XP/최고 점수를 반영한다(배치 0회 판은 제외).
5. 소리
   - 배경음악 루프(코드로 합성, 서드파티 오디오 없음)를 추가하고, 웹에서는 첫 사용자 입력 이후 시작, 탭이 숨겨지면 멈춘다. 음소거(사용자/플랫폼)면 멈춘다.
   - 연쇄, 발견, 미션 달성, 레벨 업 효과음을 추가한다. 생성기 `tool/generate_sounds.py`(표준 라이브러리만, 결정적 출력)로 만든다. 기존 place/merge/warning은 유지한다.
   - 하나의 소리 토글이 효과음과 음악을 모두 끈다.

## Acceptance Criteria
- 8단계 모두 일러스트로 그려지고 "T1" 같은 텍스트 라벨이 주된 표현으로 남지 않는다. 9 이상 티어는 8단계 그림으로 표시된다.
- 머지 시 흡수 애니메이션, 파티클, 점수 팝업이 재생되고, 연쇄 2 이상이면 배너가 뜬다. 연출 중 입력이 즉시 처리된다.
- 13칸 이상 점유 시 위험 표시가 켜지고 12칸 이하로 내려가면 꺼진다.
- 판마다 미션 3개가 보이고, 조건을 충족하면 완료 표시와 보상(Trail Axe 또는 점수 보너스)이 적용된다.
- 게임 오버 요약에 점수, 최고 점수, 신기록 여부, 최고 캠프, 최장 연쇄, 획득 XP, 레벨 진행이 표시되고, 다시 하기로 새 판이 시작된다.
- 최고 점수, 발견한 캠프, XP, 선택한 테마가 앱을 다시 열어도 유지된다. 손상된 저장값은 초기값으로 대체된다.
- 처음 만든 캠프 단계는 판 도중 배너로 알려지고, 도감에서 그림과 이름으로 보인다. 미발견은 실루엣이다.
- 테마는 요구 레벨에 도달하면 열리고, 선택한 테마의 배경이 그려진다. 잠긴 테마는 고를 수 없다.
- 배경음악은 음소거 시 멈추고, 웹에서 탭이 숨겨지면 멈췄다가 돌아오면 다시 재생된다.
- 키보드 조작(방향키/WASD, Enter/Space, X/E, R)과 튜토리얼, CrazyGames gameplayStart/Stop, 광고 흐름은 기존대로 동작한다. 새 오버레이(결과, 도감)가 열려 있으면 보드 입력은 막히고, Esc/Enter로 닫거나 다시 시작할 수 있다.
- 1280x720, 1366x768, 390x844에서 오버플로 없이 표시된다.
- 기존 테스트, CrazyGames/GamePix 빌드 자체 검사가 통과한다.

## Constraints
- 새 패키지 의존성을 추가하지 않는다. 그림은 코드로 그리고, 소리는 생성기로 만든다.
- lib/ 문자열은 영어 ASCII다(GamePix 빌드 검사). GitHub Pages 전용 결과 등록 문구는 기존 그대로 둔다.
- 머지 규칙과 점수 계산은 바꾸지 않는다(테스트 가능한 순수 컨트롤러 유지). 컨트롤러는 연출용 머지 이벤트 정보와 미션 보상용 Trail Axe 지급만 추가한다.
- GamePix: 외부 요청 없음. 모든 자산은 번들이다. 웹 업로드 zip 크기를 과도하게 키우지 않는다(음악 루프는 16000 Hz 모노 16비트, 1 MB 이하).

## Evidence
- `flutter analyze`, `flutter test`, `flutter test --platform chrome test/web`
- `flutter build web --release --base-href /MergeCamp/`, `tool/build_crazygames.sh`, `tool/build_gamepix.sh`
- 브라우저에서 1280x720, 390x844 화면 확인
- `node <harness-lab>/dist/index.js audit . --format md`

## Superseded by feature-first-run-resume
- Participation XP now also requires one merge in the run (restart farming without merges earns none).
- A mission completed by the run's final placement pays its 150 point fallback before the result is recorded; the run stays over.
