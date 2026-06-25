# MergeCamp PWA GitHub Pages 배포

## 배포 주소

`bon-on/MergeCamp` 저장소의 GitHub Pages 주소는 다음 형식을 사용한다.

```text
https://bon-on.github.io/MergeCamp/
```

## 로컬 빌드

```sh
flutter build web --release --base-href /MergeCamp/
```

빌드 결과물은 `build/web/`에 생성된다.

## 자동 배포

`.github/workflows/deploy-pages.yml`은 `main` 브랜치에 push될 때 다음 순서로 실행된다.

1. Flutter 의존성을 설치한다.
2. `flutter test`를 실행한다.
3. `flutter build web --release --base-href /MergeCamp/`로 GitHub Pages용 빌드를 만든다.
4. `build/web/`을 GitHub Pages artifact로 업로드하고 배포한다.

저장소 Settings > Pages에서 Source를 GitHub Actions로 설정해야 한다.

## iPhone 설치

1. iPhone Safari에서 `https://bon-on.github.io/MergeCamp/`를 연다.
2. 공유 버튼을 누른다.
3. `Add to Home Screen`을 선택한다.

PWA는 iOS 앱 서명 만료가 없지만, Safari/WebKit 저장공간 정책에 따라 캐시나 로컬 저장 데이터가 정리될 수 있다.
