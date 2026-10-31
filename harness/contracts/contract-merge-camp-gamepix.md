---
id: contract-merge-camp-gamepix
title: MergeCamp GamePix 웹 배포 계약
status: active
related_specs:
  - feature-merge-camp-gamepix
evidence_files:
  - docs/gamepix.md
  - reports/merge-camp-gamepix-verification.md
---

# 계약: MergeCamp GamePix 웹 배포

## Goal

같은 Flutter 코드베이스에서 SDK 없이 외부 요청이 없는 GamePix 업로드용 웹 번들을 만든다.

## Done Criteria

- `flutter analyze`, `flutter test`가 통과한다.
- `tool/build_gamepix.sh`가 성공하고 자체 검사를 통과한다.
- CrazyGames, Pages 빌드가 계속 성공한다.
- 검증 결과를 `reports/merge-camp-gamepix-verification.md`에 남긴다.

## Verification

```sh
flutter analyze
flutter test
tool/build_gamepix.sh
tool/build_crazygames.sh
flutter build web --release --base-href /MergeCamp/
node <harness-lab>/dist/index.js audit . --format md
```

## Evidence References

- docs/gamepix.md
- reports/merge-camp-gamepix-verification.md
