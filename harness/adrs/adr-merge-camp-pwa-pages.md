---
id: adr-merge-camp-pwa-pages
title: MergeCamp PWA 배포에 Flutter Web과 GitHub Pages 사용
status: accepted
related_specs:
  - feature-merge-camp-pwa-pages
---

# ADR: MergeCamp PWA 배포에 Flutter Web과 GitHub Pages 사용

## Context

개발자 서명으로 iPhone에 직접 설치한 앱은 주기적 재서명이 필요하다. MergeCamp는 오프라인 단일 플레이 퍼즐이므로 네이티브 전용 기능보다 홈 화면에서 오래 실행 가능한 배포 경로가 더 중요할 수 있다.

## Decision

기존 Flutter 모바일 앱은 유지하고, 같은 코드베이스에서 Flutter web 빌드를 만든다. `bon-on/MergeCamp` 저장소의 GitHub Pages 프로젝트 경로를 기준으로 `--base-href /MergeCamp/`를 사용한다. 웹 플랫폼에서는 AdMob 초기화와 광고 표시를 no-op으로 처리한다.

## Consequences

- App Store 제출 없이 iPhone Safari의 홈 화면 추가로 MergeCamp를 실행할 수 있다.
- 웹 배포는 iOS 앱 서명 만료 영향을 받지 않는다.
- iOS WebKit 저장공간 정책에 따라 캐시나 로컬 저장 데이터는 정리될 수 있다.
- 모바일 네이티브 빌드의 광고 경로와 웹 빌드의 무광고 경로를 조건부 import로 유지해야 한다.
