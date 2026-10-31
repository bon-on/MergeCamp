---
id: feature-sound-effects
title: MergeCamp 효과음 웹 재생과 사용자 음소거 토글
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

# 기능 명세: MergeCamp 효과음 웹 재생과 사용자 음소거 토글

## Problem
효과음(place, merge, warning)은 이미 웹(HTML `Audio`)과 네이티브 채널로 재생되지만, 플레이어가 직접 끌 수 있는 수단이 없고 CrazyGames 플랫폼 음소거에만 의존한다. iOS 오디오 세션이 `.playback`이라 무음 스위치를 무시하고 사용자의 음악을 끊는다.

## Scope
- 헤더의 `?` 버튼 옆에 소리 토글 `IconButton`을 둔다. 아이콘은 `Icons.volume_up_rounded` / `Icons.volume_off_rounded`, 툴팁은 "Sound on" / "Sound off"(현재 상태).
- 선택은 `shared_preferences` 키 `sound_muted_v1`(bool, 기본 소리 켜짐)에 저장한다. 저장소는 주입 가능한 `SoundMuteStore`로 분리하고, 읽기/쓰기 실패는 플레이를 막지 않는다.
- 실효 음소거 = 사용자 음소거 OR `GamePlatform.isAudioMuted`(CrazyGames `settings.muteAudio` 및 광고 재생 중). GamePix/Noop은 false.
- 토글을 누른 뒤 보드에 키보드 포커스를 되돌린다. 튜토리얼 카드가 열려 있는 동안은 `?`와 같이 키보드 포커스에서 제외된다. 새 단축키는 없다.
- 효과음 훅은 기존 그대로 화면 입력 처리(`tap`/`merge`/`warning`)에서 사용자 동작당 한 번 재생한다. 프레임/타이머마다 재생하지 않는다.
- 기존 네이티브 메서드(`playTap`, `playMerge`, `playWarning`, `disposeAudio`)는 유지한다. iOS 오디오 세션 카테고리는 `.ambient`로 바꾼다.
- 소리 자산: 기존 `place.wav`, `merge.wav`, `warning.wav`는 프로젝트용으로 생성한 것이며 서드파티 오디오가 없다(README에 명시). 이번 변경은 새 자산을 추가하지 않는다.

## Acceptance Criteria
- 토글을 누르면 아이콘/툴팁이 바뀌고 `sound_muted_v1`이 저장된다.
- 음소거 상태에서는 네이티브 채널/웹 오디오 재생이 호출되지 않는다(사용자 또는 플랫폼 음소거).
- 저장된 음소거는 다음 실행에서 복원된다.
- `FeedbackFx`가 참조하는 모든 오디오 자산이 디스크에 존재하고 pubspec에 포함된다.
- 기존 테스트와 CrazyGames/GamePix 빌드 검사가 통과한다.

## Constraints
- 새 패키지 의존성을 추가하지 않는다. lib/ 문자열은 영어 ASCII다.
- GamePix: 외부 요청 없음, 오디오는 번들 자산이다.

## Evidence
- `flutter analyze`, `flutter test`
- `flutter build web --release --base-href /MergeCamp/`, `tool/build_crazygames.sh`, `tool/build_gamepix.sh`
- `node <harness-lab>/dist/index.js audit . --format md`
