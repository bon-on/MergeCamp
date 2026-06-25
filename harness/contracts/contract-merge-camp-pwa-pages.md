---
id: contract-merge-camp-pwa-pages
title: MergeCamp PWA GitHub Pages 배포 계약
status: active
related_specs:
  - feature-merge-camp-pwa-pages
evidence_files:
  - docs/pwa-github-pages.md
  - reports/merge-camp-pwa-pages-verification.md
---

# 계약: MergeCamp PWA GitHub Pages 배포

## Goal

MergeCamp를 기존 모바일 앱과 같은 코드베이스에서 Flutter web/PWA로 빌드하고, `bon-on/MergeCamp` GitHub Pages 프로젝트 경로에 배포할 수 있게 한다.

## Scope

- Flutter web scaffold와 PWA manifest/HTML 메타데이터.
- GitHub Actions 기반 GitHub Pages 배포 workflow.
- 웹 플랫폼에서 네이티브 AdMob 호출을 no-op 처리하는 조건부 import.
- GitHub Pages 빌드 및 iPhone 홈 화면 추가 문서.

명시적으로 제외한다.

- App Store 제출.
- 웹 광고 수익화.
- 게임 규칙, 난이도, 보드 모델 변경.

## Done Criteria

- `flutter test`가 통과한다.
- `flutter build web --release --base-href /MergeCamp/`가 통과한다.
- 빌드 결과의 `index.html`은 `/MergeCamp/` base href를 포함한다.
- 웹 빌드는 AdMob SDK 초기화나 광고 요청 없이 실행된다.
- iOS/Android 네이티브 프로젝트 디렉터리는 유지된다.

## Verification

```sh
flutter test
flutter build web --release --base-href /MergeCamp/
node /Users/junsik.park/sources/harness-lab/dist/index.js audit . --format md
```

## Evidence References

- docs/pwa-github-pages.md
- reports/merge-camp-pwa-pages-verification.md

## 스택별 검증 메모

- Flutter web은 GitHub Pages 프로젝트 사이트 경로를 위해 `--base-href /MergeCamp/`가 필요하다.
- `google_mobile_ads`는 네이티브 모바일 경로에만 남기고, 웹에서는 조건부 import로 stub을 사용한다.
