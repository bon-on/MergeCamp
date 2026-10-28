# 검증 보고서: MergeCamp CrazyGames 웹 배포

- 명세: `harness/specs/feature-merge-camp-crazygames.md`
- ADR: `harness/adrs/adr-merge-camp-crazygames-web.md`
- 계약: `harness/contracts/contract-merge-camp-crazygames.md`
- 날짜: 2026-10-27, origin/main(게임 허브 링크, 리더보드) 위로 rebase 후 2026-10-28 재검증
- 환경: Flutter 3.41.7 / Dart 3.11.5, macOS, Google Chrome headless

## 실행한 검증

| 검증 | 결과 |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | 15개 통과 (`test/game_platform_flow_test.dart` 4개 포함), 브라우저 전용 테스트는 VM에서 제외 |
| `flutter test --platform chrome test/web` | 10개 통과: 리더보드 비활성, SDK 없음, `disabled`, init 거부, init 5초 타임아웃, gameplay 이벤트, midgame 광고 중 음소거, 광고 오류, `muteAudio` 설정, 웹 효과음 `Audio` 생성 |
| `tool/build_crazygames.sh` | 성공, 파일 34개, 28,604KB, index.html 검증 통과 |
| CrazyGames 번들 `index.html` | `<base href="./">`, SDK script가 `flutter_bootstrap.js` 앞 줄에 있음, 허브 내비게이션 바/`bon-on.github.io` 링크 없음, `--games-nav-height: 0px` |
| `flutter build web --release --base-href /MergeCamp/` | 성공, CrazyGames SDK 없음, 허브 내비게이션 바 유지 |
| 컴파일 결과 확인 | `main.dart.js`에서 효과음이 `v.G.Audio`(globalThis.Audio) 생성자로 컴파일됨 |
| headless Chrome, `http://127.0.0.1:8765/crazygames/index.html` (하위 경로, 1280x720) | 게임 화면 렌더링, 콘솔에 `CrazyGames HTML SDK initialized`, `Add settings change listener (local)`, `Requesting gameplay start (local)` 로그, 콘솔 오류 없음 |
| harness audit | Critical 0, Blocked no |

## 수용 기준 대응

| 기준 | 증빙 |
|---|---|
| analyze/test 통과 | 위 표 |
| 빌드 스크립트 산출물 | `build/crazygames/`, `build/merge-camp-crazygames.zip` 생성 확인 |
| base href, SDK script 순서 | 스크립트 내부 검사 + index.html 확인 |
| 파일 수/크기 제한 | 34개 / 약 27.9MB |
| 허브 링크 제거, 리더보드 비활성 | 빌드 스크립트 검사, headless Chrome 화면(상단 바 없음), `result registration prompt follows the platform` 위젯 테스트 |
| Pages 빌드에 SDK 없음 | grep 결과 0 |
| SDK 실패 시 계속 플레이 | `test/web/crazygames_platform_test.dart` (없음, disabled, init 거부, init 멈춤, 광고 오류) |
| 재시작 시 광고 대기, 진행 중 재시작은 광고 없음 | `game_platform_flow_test.dart` |
| gameplay 이벤트 순서 | `game_platform_flow_test.dart` |

## 검증하지 않은 것

- 실제 브라우저에서 게임 오버 → midgame 광고 → 재시작 흐름(클릭 자동화 없이 위젯 테스트로만 확인).
- 실제 브라우저에서 소리가 들리는지(가짜 `Audio`로 생성/재생 호출만 확인).
- Safari, 모바일 브라우저, CrazyGames QA tool, 실제 CrazyGames 도메인.
- 모바일 네이티브 빌드(`flutter build apk/ios`). 이번 변경에서 네이티브 코드와 AdMob 경로는 수정하지 않았다.

## 코드 리뷰

`code-reviewer` 1차 리뷰에서 High 1건(웹 `Audio` 바인딩에 `@JS('Audio')` 누락으로 효과음이 매번 예외), Medium 3건(SDK init 무한 대기, 560px 폭 제한이 모바일/태블릿에도 적용, SDK 실패 경로 테스트 없음), Low 4건이 나왔다. High와 Medium은 모두 수정했다. Low 중 광고 타임아웃 주석, `_restartRun` 예외 처리, 빌드 스크립트 grep 처리는 반영했고, 광고 대기 중 탭 무시 테스트와 `didUpdateWidget` 처리는 테스트 전용 경로라 보류했다.

## 기존 감사 경고 (이번 변경과 무관)

- `AGENTS.md`가 `harness/workflow.md`를 참조하지 않음, `CLAUDE.md`/`harness/workflow.md`/`harness/maintenance.json` 없음.
