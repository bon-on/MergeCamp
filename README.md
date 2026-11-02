# MergeCamp

MergeCamp는 iPhone과 Android를 위한 모바일 머지 퍼즐 게임이다. 플레이어는 4x4 보드에 캠프 타일을 놓고, 연쇄 머지를 만들며, 시간이 아니라 보드 압박이 점점 커지는 흐름에서 오래 버틴다.

## 핵심 규칙

- 빈 칸을 탭하면 다음 타일이 배치된다.
- 인접한 같은 타일 3개 이상이 연결되면 더 높은 티어로 머지된다.
- 고정된 제한 시간은 없고, 보드가 막히면 게임이 끝난다.
- 배치 횟수가 늘수록 티어 범위와 압박이 함께 상승한다.
- 키보드: 방향키/WASD로 커서 이동, Enter/Space로 배치, X(또는 E)로 Trail Axe 사용, R로 재시작. 결과 화면에서는 Enter/Space/R로 다시 하기, 도감은 Esc로 닫는다.
- 첫 실행 시 3단계 How to play 카드가 뜬다(Skip 가능). 상단 "?" 버튼으로 다시 볼 수 있다.
- 배치, 머지, 경고 동작은 효과음과 햅틱 피드백을 함께 사용한다.

## 목표와 진행

- 8단계 캠프(Trail Tent → Cook Fire → Supply Shed → Scout Cabin → Signal Tower → Base Lodge → Summit Camp → Star Observatory)는 모두 코드로 그린 벡터 일러스트다.
- 머지하면 흡수 애니메이션, 파티클, "+점수" 팝업이 나오고, 연쇄 머지는 "Chain x2!" 배너로 강조된다. 보드가 13칸 이상 차면 가장자리가 붉게 맥동한다. 연출은 입력을 막지 않는다.
- 판마다 미션 3개가 주어진다. 달성하면 Trail Axe 1개(상한이면 +150점)와 30 XP를 받고, 세 개를 모두 끝내면 다음 세트가 열린다.
- 판이 끝나면(보드 막힘) 요약 화면에서 점수, 최고 점수, 최고 캠프, 최장 연쇄, 완료 미션, 획득 XP를 보여준다. 판 도중 재시작도 판 종료로 반영된다.
- 캠프 도감(앨범 버튼)에서 발견한 캠프와 미발견 실루엣을 본다. 처음 만든 캠프는 판 도중 배너로 알린다.
- 캠프 레벨이 오르면 테마가 열린다: Summer Lv1, Autumn Lv3, Snow Lv6, Night Lv10(꾸미기 전용).
- 진행도(최고 점수, 도감, XP, 테마)는 `shared_preferences` 키 `camp_progress_v1`에 저장된다.
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
