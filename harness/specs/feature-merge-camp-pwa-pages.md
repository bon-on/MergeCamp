---
id: feature-merge-camp-pwa-pages
title: MergeCamp PWA GitHub Pages 배포
status: active
owner: games
related_adrs:
  - adr-merge-camp-pwa-pages
related_contracts:
  - contract-merge-camp-pwa-pages
required_evidence:
  - flutter-tests
  - flutter-web-build
  - harness-audit
---

# 기능 명세: MergeCamp PWA GitHub Pages 배포

## Problem

iPhone에 직접 설치한 개발 빌드는 서명 만료로 계속 실행되지 않을 수 있다. App Store 출시 없이도 사용자가 홈 화면에서 MergeCamp를 계속 실행할 수 있는 웹/PWA 배포 경로가 필요하다.

## Scope

- 기존 iOS와 Android 네이티브 프로젝트는 유지한다.
- Flutter web 빌드를 추가해 GitHub Pages에서 실행 가능하게 한다.
- GitHub Pages 프로젝트 주소인 `/MergeCamp/` 하위 경로에서 정적 자산이 올바르게 로드되게 한다.
- iOS 홈 화면 추가에 필요한 PWA manifest와 HTML 메타데이터를 MergeCamp 이름과 색상으로 설정한다.
- 웹 빌드에서는 네이티브 AdMob 플러그인에 의존하지 않고 광고 영역을 비활성화한다.
- GitHub Actions로 테스트 후 web build를 GitHub Pages에 배포한다.

## Acceptance Criteria

- `flutter test`가 통과한다.
- `flutter build web --release --base-href /MergeCamp/`가 통과한다.
- 웹 빌드는 `https://bon-on.github.io/MergeCamp/` 경로 기준으로 asset과 bootstrap 파일을 찾는다.
- iOS와 Android 네이티브 소스 디렉터리는 제거하거나 대체하지 않는다.
- PWA manifest의 앱 이름, 설명, theme/background color가 MergeCamp에 맞게 설정된다.
- 웹 플랫폼에서는 AdMob 초기화, banner, interstitial 요청이 no-op으로 처리된다.

## Constraints

- MVP는 오프라인 단일 플레이를 유지한다.
- 머지 규칙과 난이도 상승은 결정적이어야 하며 웹 배포 작업에서 변경하지 않는다.
- 광고 SDK는 네이티브 모바일 배포에만 적용하고, 웹 배포는 광고 없이 실행한다.

## Evidence

- `flutter test`
- `flutter build web --release --base-href /MergeCamp/`
- `node /Users/junsik.park/sources/harness-lab/dist/index.js audit . --format md`
