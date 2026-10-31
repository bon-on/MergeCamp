# CrazyGames 배포

MergeCamp는 `--dart-define=CRAZYGAMES=true`로 빌드하면 CrazyGames HTML5 SDK v3를 사용한다. 이 플래그가 없는 웹 빌드(GitHub Pages)와 모바일 빌드는 SDK를 쓰지 않는다.

## 빌드

```sh
tool/build_crazygames.sh
```

결과물:

- `build/crazygames/`: 업로드할 번들 폴더
- `build/merge-camp-crazygames.zip`: 포털 업로드용 zip

스크립트가 하는 일:

1. `flutter build web --release --no-web-resources-cdn --dart-define=CRAZYGAMES=true`
2. `index.html`의 base href를 `./`로 바꾸고, `flutter_bootstrap.js` 앞에 SDK script를 넣는다.
3. Bon-on 게임 허브 내비게이션 바를 지우고 높이 변수를 0으로 바꾼다(포털은 외부 링크를 허용하지 않는다).
4. `*.symbols` 디버그 파일을 지우고, 파일 수(1500개 이하)와 전체 크기(50MB 이하)를 검사한다.

## 테스트

```sh
flutter test                                # 게임 흐름 (VM)
flutter test --platform chrome test/web     # SDK 어댑터, 웹 효과음 (Chrome)
```

## 로컬 확인

```sh
cd build && python3 -m http.server 8765
# 브라우저에서 http://localhost:8765/crazygames/index.html
```

`localhost`에서는 SDK `environment`가 `local`이 되고, 광고 대신 안내 오버레이가 뜬다. 브라우저 콘솔에서 `Requesting gameplay start` 같은 SDK 로그를 확인할 수 있다. 음소거 동작은 `?muteAudio=true`를 붙여 확인한다.

## SDK 연동 지점

| 시점 | 호출 |
|---|---|
| 앱 시작 | `SDK.init()` 후 `environment`가 `crazygames`/`local`이 아니면 SDK를 끈다 |
| 첫 프레임 | `game.gameplayStart()` |
| 보드가 막혀 게임 오버 | `game.gameplayStop()` |
| 게임 오버 후 Restart | `ad.requestAd('midgame')`, 광고가 끝나거나 실패하면 새 판 시작 + `gameplayStart()` |
| 광고 재생 중, `settings.muteAudio` | 효과음 끔 |
| 게임 오버 | Bon-on 리더보드 등록 안내를 띄우지 않음 (Pages/모바일에서는 띄움) |

진행 중에 상단 재시작 버튼을 누르면 광고 없이 바로 새 판을 시작한다. 광고 간격 제한(`adCooldown`, 보통 3분)은 SDK가 처리하고, 오류가 나도 게임은 계속된다.

## 업로드 체크리스트

- [ ] 개발자 포털에서 Basic Launch로 먼저 제출한다(Basic Launch에서는 광고가 꺼진다).
- [ ] 지원 방향은 세로(portrait)로 등록한다. 데스크톱에서는 가로 화면 가운데에 560px 폭으로 표시된다.
- [ ] 썸네일과 설명 문구를 준비한다(`docs/store-listing-copy.md` 참고).
- [ ] 포털의 QA tool에서 로딩, gameplay 이벤트, midgame 광고를 확인한다.

## 알려진 제한

- 키보드 조작은 없다. 클릭/탭만으로 전체 플레이가 가능하다.
- 보상형 광고, 배너, Data/User 모듈은 아직 쓰지 않는다.
- Roboto는 `assets/fonts/`에 번들되어 있어 런타임에 Google 폰트 CDN 요청이 없다.
