---
id: contract-merge-camp-crazygames
title: MergeCamp CrazyGames 웹 배포 계약
status: active
related_specs:
  - feature-merge-camp-crazygames
evidence_files:
  - docs/crazygames.md
  - reports/merge-camp-crazygames-verification.md
---

# 계약: MergeCamp CrazyGames 웹 배포

## Goal

같은 Flutter 코드베이스에서 CrazyGames HTML5 SDK v3를 연동한 업로드용 웹 번들을 만든다.

## Scope

- `GamePlatform` 인터페이스, no-op 구현, CrazyGames `dart:js_interop` 어댑터.
- 게임 화면의 gameplay 이벤트, 재시작 전 midgame 광고, 광고 중 입력/효과음 차단.
- 웹 효과음 재생과 데스크톱 레이아웃 폭 제한.
- `tool/build_crazygames.sh`와 `docs/crazygames.md`.

명시적으로 제외한다.

- 보상형/배너 광고, Data/User 모듈, 키보드 조작.
- 게임 규칙, 난이도, 점수 변경.
- 포털 업로드와 제출.

## Done Criteria

- `flutter analyze`, `flutter test`가 통과한다.
- `tool/build_crazygames.sh`가 성공하고 번들 index.html 검증을 통과한다.
- GitHub Pages 빌드 결과에는 CrazyGames SDK script가 없다.
- 검증 결과를 `reports/merge-camp-crazygames-verification.md`에 남긴다.

## Verification

```sh
flutter analyze
flutter test
flutter test --platform chrome test/web
tool/build_crazygames.sh
flutter build web --release --base-href /MergeCamp/
node <harness-lab>/dist/index.js audit . --format md
```

## Evidence References

- docs/crazygames.md
- reports/merge-camp-crazygames-verification.md
