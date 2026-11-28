# GamePix 배포

`--dart-define=GAMEPIX=true`로 빌드하면 GamePix SDK v3(수동 lifecycle, feature-gamepix-sdk)를 불러오는 GamePix 번들이 된다. 그 밖의 서드파티 script, 외부 링크, 결과 업로드, 외부 폰트 요청은 없다. 전면 광고는 게임 오버 뒤 새 판에서 2분 간격으로, 보상형 광고는 Second Wind에서만 나온다.

## 빌드

```sh
tool/build_gamepix.sh
```

결과물: `build/gamepix/`(번들 폴더), `build/merge-camp-gamepix.zip`(업로드용, `index.html`이 zip 루트).

스크립트가 하는 일:

1. `flutter build web --release --base-href / --no-web-resources-cdn --dart-define=GAMEPIX=true`
2. `<base href="./">`로 바꾸고, 허브 내비게이션 바와 높이를 지우고, 템플릿 주석(문서 URL)을 지운다.
3. index.html `</head>` 앞에 `window.GamePixConfig = { lifecycle: 'manual' }`과 GamePix SDK script를 넣는다.
4. 검사: SDK script가 한 번만 bootstrap보다 먼저 있음, `crazygames`/`bon-on.github.io`/SDK 외 `http(s)://`가 index.html에 없음, viewport `user-scalable=no`, `touch-action: none`, 번들에 `crazygames-sdk` 없음, `FontManifest.json`에 Roboto, zip 루트의 `index.html`.
5. 파일 수/크기와 `main.dart.js`의 `crazygames` 문자열 수를 출력한다.

## 로컬 확인

```sh
cd build && python3 -m http.server 8765
# http://localhost:8765/gamepix/index.html (640x480, 360x640 창에서도 확인)
```

## 업로드 메모

- SDK integration: 체크(GamePix SDK v3, 전면/보상형 광고, pause/resume, localStorage 동기화)
- 아이콘 256x256, 커버 1360x850 (아직 만들지 않음)
- 방향: 세로 위주(데스크톱에서는 560px 폭 열이 가운데에 표시됨). Desktop/Mobile friendly로 등록한다.
- 입력: 마우스/터치 탭, 키보드(방향키/WASD, Enter/Space, X, R).
- 오디오: 웹 효과음은 번들 자산을 브라우저 `Audio`로 재생한다(외부 요청 없음).
- 언어: 영어(기본).
- 폰트: Roboto를 `assets/fonts/`에 번들한다(라이선스 `assets/fonts/Roboto_LICENSE.txt`). 그래서 런타임에 fonts.gstatic.com 요청이 없다. `main.dart.js`/`flutter_bootstrap.js`에는 gstatic URL 문자열이 남지만 사용되지 않는다.
- 일시정지: 탭이 숨겨지면 브라우저가 rAF를 멈추므로 Flutter 루프도 멈춘다.
