# MergeCamp

MergeCamp는 iPhone과 Android를 위한 모바일 머지 퍼즐 게임이다. 플레이어는 4x4 보드에 캠프 타일을 놓고, 연쇄 머지를 만들며, 시간이 아니라 보드 압박이 점점 커지는 흐름에서 오래 버틴다.

## 핵심 규칙

- 빈 칸을 탭하면 다음 타일이 배치된다.
- 인접한 같은 타일 3개 이상이 연결되면 더 높은 티어로 머지된다.
- 고정된 제한 시간은 없고, 보드가 막히면 게임이 끝난다.
- 배치 횟수가 늘수록 티어 범위와 압박이 함께 상승한다.
- 키보드: 방향키/WASD로 커서 이동, Enter/Space로 배치, X(또는 E)로 Trail Axe 사용, R로 재시작.
- 첫 실행 시 3단계 How to play 카드가 뜬다(Skip 가능). 상단 "?" 버튼으로 다시 볼 수 있다.
- 배치, 머지, 경고 동작은 효과음과 햅틱 피드백을 함께 사용한다.

## 로컬 실행

1. Flutter와 iOS/Android 툴체인을 설치한다.
2. `flutter pub get`을 실행한다.
3. `flutter test`를 실행한다.
4. `flutter run`을 실행한다.

## CrazyGames 웹 번들

`tool/build_crazygames.sh`를 실행하면 `build/crazygames/`와 업로드용 `build/merge-camp-crazygames.zip`이 생성된다. 자세한 내용은 `docs/crazygames.md`를 참고한다.
