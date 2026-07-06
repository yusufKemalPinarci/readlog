# Phase 0 Baseline — fix/code-review (2026-07-07)

Recorded before any code change, so new breakage is attributable.

## `flutter analyze --no-pub`
- **45 issues, 0 errors** (44 info + 1 warning).
- Note: plain `flutter analyze` (with implicit pub-get) fails on this machine with
  `Building with plugins requires symlink support` → needs Windows **Developer Mode**.
  `--no-pub` analyzes fine once deps are resolved.
- Breakdown by rule:
  - 27 `prefer_const_constructors`
  - 13 `use_build_context_synchronously`
  - 2 `prefer_final_locals`
  - 1 `unused_element_parameter` (**warning** — `filterDate` in book_reading_logs_screen.dart:109)
  - 1 `prefer_conditional_assignment`
  - 1 `deprecated_member_use`

## `flutter test`
- **105 pass / 33 fail.**
- All 33 failures are in `test/theme/app_theme_test.dart`, single root cause:
  `GoogleFonts.config.allowRuntimeFetching is false but font CrimsonText-Regular was not
  found in the application assets.`
  → Fixed by **T2.25** (bundle Crimson Text TTFs + declare in pubspec).

## `flutter build apk --release`
- Not run: requires Windows Developer Mode (symlink support) to build plugins.
- Phase X step 3 (release fails without keystore / succeeds with) will be verified by
  **code inspection of `android/app/build.gradle.kts`** unless Developer Mode is enabled.
