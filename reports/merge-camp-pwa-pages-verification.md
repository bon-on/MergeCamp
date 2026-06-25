# MergeCamp PWA GitHub Pages Verification

## Scope

Verification for `feature-merge-camp-pwa-pages`.

## Commands

```sh
flutter test
flutter build web --release --base-href /MergeCamp/
flutter analyze
node /Users/junsik.park/sources/harness-lab/dist/index.js audit . --format md
node /Users/junsik.park/sources/harness-lab/dist/index.js plan harness/specs/feature-merge-camp-pwa-pages.md --format text
```

## Results

- `flutter test`: passed, 7 tests.
- `flutter build web --release --base-href /MergeCamp/`: passed, built `build/web`.
- `flutter analyze`: passed, no issues found.
- Harness audit: passed, blocked `no`, 0 critical findings, 0 warnings.
- Harness plan: passed, blockers `none`.

## Build Path Check

`build/web/index.html` contains:

```html
<base href="/MergeCamp/">
```

`build/web/manifest.json` contains `MergeCamp` for both `name` and `short_name`.

## Notes

- Web builds use no-op ad service and banner implementations.
- Native iOS and Android project directories remain in the repository.
