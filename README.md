# MergeCamp

MergeCamp는 iPhone과 Android를 위한 모바일 머지 퍼즐 게임이다. 플레이어는 4x4 보드에 캠프 타일을 놓고, 연쇄 머지를 만들며, 시간이 아니라 보드 압박이 점점 커지는 흐름에서 오래 버틴다.

## 핵심 규칙

- 빈 칸을 탭하면 다음 타일이 배치된다.
- 인접한 같은 타일 3개 이상이 연결되면 더 높은 티어로 머지된다.
- 고정된 제한 시간은 없고, 보드가 막히면 게임이 끝난다.
- 배치 횟수가 늘수록 티어 범위와 압박이 함께 상승한다.
- 키보드: 방향키/WASD로 커서 이동, Enter/Space로 배치, X(또는 E)로 Trail Axe 사용, C로 Shift 모드(커서 위치에서 Enter로 캠프 선택, 방향키/WASD로 방향 선택, Esc 취소), R로 재시작. 결과 화면에서는 Enter/Space/R로 다시 하기, 도감과 꾸미기 화면은 Esc로 닫는다(꾸미기 화면은 방향키/Tab 이동, Enter/Space 선택).
- 첫 실행 시 3단계 How to play 카드가 뜬다(Skip 가능). 상단 "?" 버튼으로 다시 볼 수 있다.
- 배치, 머지, 경고 동작은 효과음과 햅틱 피드백을 함께 사용한다.

## 목표와 진행

- 8단계 캠프(Trail Tent → Cook Fire → Supply Shed → Scout Cabin → Signal Tower → Base Lodge → Summit Camp → Star Observatory)는 모두 코드로 그린 벡터 일러스트다.
- 머지하면 흡수 애니메이션, 파티클, "+점수" 팝업이 나오고, 연쇄 머지는 "Chain x2!" 배너로 강조된다. 보드가 13칸 이상 차면 가장자리가 붉게 맥동한다. 연출은 입력을 막지 않는다.
- 판마다 미션 3개가 주어진다. 달성하면 Trail Axe 1개(상한이면 +150점)와 30 XP를 받고, 세 개를 모두 끝내면 다음 세트가 열린다.
- Shift: 캠프 하나를 골라 위/아래/왼쪽/오른쪽으로 한 칸 옮긴다. 도착 칸에 다른 캠프가 있으면 그 캠프는 삭제되고(점수 없음), 도착 칸에서 3개 이상 맞붙으면 바로 합쳐진다. 한 번에 4칸 이상 합치거나 3연쇄를 만들거나 한 판에서 처음 6단계 캠프를 만들면 1개를 받고, "Merge N+ tiles at once" 미션 보상은 Shift를 먼저 주지만 그 배치가 이미 Shift를 줘서 보통 Trail Axe가 된다(최대 1개, 판이 끝나면 사라짐). 배치 횟수와 새 타일 순서는 바꾸지 않고, 보드 밖이나 빈 칸이면 쓰지 않은 채로 남는다(`feature-camp-shift`).
- 판이 끝나면(보드 막힘) 요약 화면에서 점수, 최고 점수, 최고 캠프, 최장 연쇄, 완료 미션, 획득 XP를 보여준다. 판 도중 재시작도 판 종료로 반영된다.
- 캠프 도감(앨범 버튼)에서 발견한 캠프와 미발견 실루엣을 본다. 처음 만든 캠프는 판 도중 배너로 알린다.
- 캠프 레벨이 오르면 테마가 열린다: Summer Lv1, Autumn Lv3, Snow Lv6, Night Lv10(꾸미기 전용).
- 캠프 레벨 1~25마다 스티커 1장(25종, Lv5/10/15/20/25는 금테 희귀)을 받는다. 새 스티커는 보드 주변 슬롯 16개(위 5, 아래 5, 좌우 3씩) 중 첫 빈 칸(위 줄 왼쪽부터)에 자동으로 붙고, Decorate 버튼(HUD, 결과 화면)에서 붙이기/바꾸기/떼기를 한다. 좁은 세로 화면에서는 위/아래 10칸만 보드 옆에 보인다. 예전 10칸 배치 저장은 불러올 때 같은 면의 슬롯으로 옮겨진다. 규칙, 점수, XP에는 영향이 없다.
- 오늘의 캠프(헤더의 불꽃 버튼, 아직 안 했으면 빨간 점): 하루에 한 번 같은 날짜 시드로 모든 플레이어에게 같은 타일 순서가 나온다. 5번 이상 놓고 한 번 이상 머지한 판이 그날 처음 반영되면 연속 출석(streak)이 늘고 보너스 XP 40~80을 받는다. 하루를 걸러도 한 번은 유지(grace)되고 7일 보상 뒤 다시 채워진다. 같은 날 다시 하면 점수만 갱신된다. 결과 화면에 streak, 오늘 최고 점수, 내일 보상이 나오고 Try again/Free play를 고른다. 규칙과 점수는 일반 판과 같다(`feature-daily-camp`).
- 머지 연출은 약 210ms(연쇄마다 +150ms) 안에 결과가 보이도록 짧게 잡았다(`feature-merge-feel-timing`).
- 진행도(최고 점수, 도감, XP, 테마, 스티커 배치, 오늘의 캠프 streak)는 `shared_preferences` 키 `camp_progress_v1`에 저장된다.
- 화면 구성: 가로가 넓으면 보드를 가운데 두고 좌우 패널(캠프 레벨, 미션 / 점수, 다음 타일, Trail Axe, 메뉴)을, 좁으면 위아래로 쌓는다. 코드는 `lib/src/game/merge_camp_screen.dart`(상태, 입력, 플랫폼 흐름)와 `lib/src/game/ui/`(레이아웃, 보드, 연출, 오버레이)로 나뉜다.

## 로컬 실행

1. Flutter와 iOS/Android 툴체인을 설치한다.
2. `flutter pub get`을 실행한다.
3. `flutter test`를 실행한다.
4. `flutter run`을 실행한다.

## CrazyGames 웹 번들

`tool/build_crazygames.sh`를 실행하면 `build/crazygames/`와 업로드용 `build/merge-camp-crazygames.zip`이 생성된다. 자세한 내용은 `docs/crazygames.md`를 참고한다.

## GamePix 웹 번들

`tool/build_gamepix.sh`를 실행하면 `build/gamepix/`와 업로드용 `build/merge-camp-gamepix.zip`이 생성된다(SDK 없음, 외부 링크/광고/결과 업로드 없음). 자세한 내용은 `docs/gamepix.md`를 참고한다.

## 소리

모든 소리는 이 프로젝트를 위해 생성한 파일이며 서드파티 오디오를 사용하지 않는다.

| 파일 | 용도 |
| --- | --- |
| `place.wav`, `merge.wav`, `warning.wav` | 타일 배치, 머지, 보드 위험 (기존) |
| `chain.wav` | 연쇄 머지 (밝게 올라가는 3음) |
| `discover.wav` | 새 캠프 단계 발견 |
| `mission.wav` | 미션 달성 |
| `level_up.wav` | 캠프 레벨 업 |
| `music_loop.wav` | 배경음악 루프 (C 장조, 100 BPM, 28.8초, 16 kHz 모노) |

`tool/generate_sounds.py`(Python 3 표준 라이브러리만, 결정적 출력)가 `chain`, `discover`, `mission`, `level_up`, `music_loop`을 만든다: `python3 tool/generate_sounds.py`. 기존 세 효과음은 다시 쓰지 않는다. 새 소리가 필요하면 내려받지 말고 이 스크립트에 추가한다. 음악 루프는 끝과 처음이 이어지도록 원형 타임라인에서 렌더링한다.

헤더의 스피커 버튼 하나로 효과음과 음악을 함께 켜고 끌 수 있으며 선택은 `shared_preferences`의 `sound_muted_v1`에 저장된다. CrazyGames 플랫폼 음소거와 광고 재생 중 음소거는 사용자 설정과 함께 적용된다. 웹에서는 첫 사용자 입력 뒤에 음악이 시작되고 탭이 숨겨지면 멈춘다. iOS는 오디오 세션 `.ambient`를 사용해 무음 스위치를 따르고 다른 앱의 음악을 끊지 않는다.

## 폰트 라이선스

웹 빌드가 외부 폰트를 받지 않도록 Roboto(Apache License 2.0)를 `assets/fonts/`에 번들한다. 라이선스 전문은 `assets/fonts/Roboto_LICENSE.txt`에 있다.
