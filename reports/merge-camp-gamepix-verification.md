# 검증 보고서: MergeCamp GamePix 웹 배포

- 명세: `harness/specs/feature-merge-camp-gamepix.md`
- ADR: `harness/adrs/adr-merge-camp-gamepix-web.md`
- 계약: `harness/contracts/contract-merge-camp-gamepix.md`
- 날짜: 2026-10-31
- 환경: Flutter (Homebrew), macOS, Google Chrome headless

## 실행한 검증

| 검증 | 결과 |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | 47개 통과 (`test/gamepix_platform_test.dart` 3개 포함) |
| `flutter test --platform chrome test/web` | 통과 |
| `tool/build_gamepix.sh` | 성공: `index.html`이 zip 루트, `crazygames-sdk`/`bon-on.github.io`/외부 URL 없음, 상대 base, `FontManifest.json`에 Roboto, 파일 약 37개, zip 약 11.6MB |
| `main.dart.js`의 `crazygames` 문자열 | 0개 |
| `tool/build_crazygames.sh` | 성공, Roboto 번들, SDK script 유지 |
| `flutter build web --release --base-href` (Pages) | 성공, SDK script 없음, 허브 내비게이션 유지 |
| headless Chrome 640x480, 360x640 | 오버플로/잘림 없음(scrollWidth/Height = 뷰포트), 로딩 화면은 첫 프레임에 사라짐, 외부 호스트 요청 0 |

## 알려진 사항

- `flutter_bootstrap.js`/`main.dart.js`/인라인 로더에 gstatic CanvasKit 및 폰트 URL 문자열이 엔진 상수로 남지만 `useLocalCanvasKit`과 번들 Roboto 때문에 요청되지 않는다.
- 번들 크기는 CanvasKit 변형 파일들 때문에 약 29MB다.
