# PLAN: Code Review Fixes — Libris (readlog-main)

> Source: full-project code review (2026-07-06). 10 criticals, ~26 warnings, ~20 suggestions.
> Mode: PLANNING ONLY — no code has been changed yet.
> Project type: **MOBILE (Flutter)** → primary agent: `mobile-developer` (per kit routing, mobile is full-stack).
> All paths below are relative to `readlog-main/`.

---

## Overview

Fix every finding from the code review, ordered so that (a) permanent-data-loss bugs die first, (b) shared prerequisites (safe parsing, `copyWith` sentinels, unit-safe formatters) land before the fixes that depend on them, and (c) refactors/dedup happen only after behavior is correct, so refactors never mask a behavior change.

### Decisions (Socratic Gate — answered by user)

| Decision | Choice |
|---|---|
| Fake auth feature (`features/auth/`) | **Delete entirely** (screens, AuthService, unused google.png reference) |
| Daily-goal feature | **Wire it up**: fix crash, add navigation entry, consume the goal in daily progress UI |
| Privacy claim vs behavior | **Make app match claim**: disable Android auto-backup, bundle fonts locally, no runtime font fetching |

### Success Criteria

- All 10 criticals fixed and covered by a regression test where testable.
- All warnings fixed; all suggestions applied or explicitly dropped with a note in this file.
- `flutter analyze` clean; `flutter test` green; release build **fails loudly** without a keystore (by design).
- Smoke checklist (Phase X) passes on a device/emulator.
- No screen shows fabricated data (hardcoded streak, fake category, stale version).

---

## Phase 0 — Safety Net (before any fix)

| ID | Task | Verify |
|---|---|---|
| T0.1 | Create branch `fix/code-review` off `main`. | `git branch --show-current` = fix/code-review |
| T0.2 | Baseline: run `flutter analyze` and `flutter test`; record current failures (if any) so new breakage is attributable. | Baseline output saved in PR/commit message |
| T0.3 | Characterization tests for the two riskiest surfaces **before** touching them: `FinishReadingVm.saveAndMarkRead` (current wrong 60× behavior) and `ImageStorageService.saveImage` (source==target deletion). Write tests asserting the **correct** behavior; they fail now, pass after Phase 1. | Tests exist and fail for the right reason |

---

## Phase 1 — Criticals

### Group A: Time & unit corruption

| ID | Fix | Files | INPUT → OUTPUT → VERIFY |
|---|---|---|---|
| T1.1 | **60× inflation.** Rename VM field/setter to `finalTotalMinutes`; screen already sends minutes — remove the `hours * 60` multiplication in `saveAndMarkRead` (lines 185–192). Audit both callback paths (manual entry line 402–409, timer path 412–416). | `finish_reading_vm.dart`, `finish_reading_flow_screen.dart` | Finish book after 90-min session → `book.totalMinutes == 90` → unit test from T0.3 passes |
| T1.2 | **Direct-finish double count.** `loadTotalMinutesForBook` prefill must not be re-saved as a new log. On direct finish, create the final log with **only the new session's duration** (0 if none) and pass the prefilled total solely to `markAsRead(finalMinutes:)`. | `finish_reading_vm.dart:93–105, 148–159` | Book with 5 logs / 300 min → "Kitabı Bitir" → logs total still 300 (+0-min final marker or none), book total 300 |

### Group B: Storage integrity (order matters: T1.3 → T1.4 → T1.5 → T1.6)

| ID | Fix | Files | INPUT → OUTPUT → VERIFY |
|---|---|---|---|
| T1.3 | **Safe deserialization.** `Book.fromJson`/`ReadingLog.fromJson`/`UserProfile.fromJson`: guard enum index (`shelf` clamp/fallback to `toRead`), `DateTime.tryParse` with fallback, type-tolerant int/double reads. Add `static Book? tryParse(Map json)` returning null on garbage. Repositories skip-and-log unparseable records instead of throwing. | `book.dart:110`, `reading_log.dart:72–85`, `user_profile.dart`, both repositories | JSON with `"shelf": 7` / bad date → app boots, record skipped → unit tests with malformed fixtures |
| T1.4 | **Corrupt ≠ empty.** `LocalStorageService`: on decode failure, do NOT return `[]` — keep the raw blob, write it to `books_data.corrupt.bak`, and surface a `StorageCorruptionException`/flag so repositories enter a read-only error state instead of silently starting empty. Additionally write a rolling `.bak` of the previous blob before every save. Use eager `List<Map<String,dynamic>>.from` so element-type errors are caught inside the guard. | `local_storage_service.dart:25–49`, repositories | Corrupt the prefs string in a test → load reports corruption, next save does NOT wipe the blob, `.bak` exists |
| T1.5 | **Backup import validation + transactionality.** Validate every record via `tryParse` from T1.3 **before** persisting anything; reject the whole import with a specific error message if any record is invalid (or import valid subset behind an explicit user choice — implement reject-all first, simplest). Reorder: parse+validate → extract files → write prefs **last**; snapshot prefs first and restore on any failure. Fix v2-`backup.json` relative-path handling in `_cleanInvalidPath` (null out non-absolute media paths too) and import `profile`/`settings` blocks consistently in the JSON path. | `data_backup_service.dart:215–303, 427–470` | Import truncated/hand-edited backup → clear error, data untouched → integration test with bad fixture |
| T1.6 | **`theme_mode` key collision.** Single owner: keep `ThemeManager` (string values `light/dark/system`) as canonical; `LocalStorageService`/backup use key `theme_mode_v2` or delegate to ThemeManager's representation. Add startup migration: read old key defensively (`prefs.get()` as Object, handle bool or String), rewrite canonical, remove ambiguity. Backup export/import maps to the canonical form. | `theme_manager.dart:24`, `local_storage_service.dart:12,62–68`, `data_backup_service.dart:38,262` | Set dark theme → export succeeds; import backup → next launch boots with correct theme → test both legacy value types |

### Group C: Cover image lifecycle

| ID | Fix | Files | INPUT → OUTPUT → VERIFY |
|---|---|---|---|
| T1.7 | **Cover self-deletion.** `saveImage`: if `sourcePath == targetPath` (canonicalized) return target unchanged; otherwise copy to `cover_<id>.jpg.tmp` then atomically rename over target (no pre-delete). On failure, old file survives. Apply identically in `ProfileImageStorageService` (merged later in T4.4). | `image_storage_service.dart:24–45`, `profile_image_storage_service.dart` | Edit a book's title only, save → cover still on disk and displayed → T0.3 test passes |
| T1.8 | **`copyWith` sentinels.** Introduce sentinel-based `copyWith` (e.g. `Object? coverImagePath = _unset`) on `Book`, `ReadingLog`, `FinishReadingState` so nullable fields can be cleared. Then: "Resmi Kaldır" persists `coverImagePath: null`; rating/review clearable; dead `error` field either works or is removed. **Prerequisite for T2.2, T2.x rating fixes.** | `book.dart:79`, `reading_log.dart:32–56`, `finish_reading_vm.dart:21` | `book.copyWith(coverImagePath: null).coverImagePath == null` → unit test |

### Group D: Reorder

| ID | Fix | Files | INPUT → OUTPUT → VERIFY |
|---|---|---|---|
| T1.9 | **Reorder logic.** In `reorderBooks`: apply `if (newIndex > oldIndex) newIndex -= 1;` and accept `newIndex == length` (drop at end). Persist with a single batched save instead of one `upsert` per book. In `home_screen`: only enable drag when shelf is in manual order **and** search is empty (`buildDefaultDragHandles: false` + conditional handles, or map filtered indices back to unfiltered ids). | `books_vm.dart:177–193`, `home_screen.dart:687–716, 812–835` | Drag first book to end → lands at end; drag while searching → either disabled or correct book moves → unit tests for index math |

### Group E: Broken screens/routes

| ID | Fix | Files | INPUT → OUTPUT → VERIFY |
|---|---|---|---|
| T1.10 | **Edit menu dead-end.** Route "Düzenle" per shelf: `toRead`/`reading` → `Routes.editBook`, `read` → `Routes.editCompletedBook`. Remove or wire the dead `onEdit`/`onDelete`/`onFinish` params of `_BooksList`. | `home_screen.dart:336–431` | "Düzenle" works on all three shelves |
| T1.11 | **Daily goal wire-up.** Fix default conflict (repo default → 45, matching `UserProfile`); replace the `_selectedMinutes == 45` build-time hack with one-shot init from profile (`initState`/first-data); clamp slider input to `[5,180]`. Add navigation entry (profile screen row + settings). Consume the goal: daily progress indicator on profile/home ("today X / goal Y min"), guarding division by zero. | `daily_goal_screen.dart:61–63,110–146`, `profile_repository.dart:14–19`, `profile_screen.dart`, `user_profile.dart` | Fresh install → open screen, no crash, 45 preselected, preset buttons stick; goal visible somewhere in UI |
| T1.12 | **Calendar day-detail empty.** Drop the `shelf == BookShelf.read` filter; include logs whose book exists on any shelf, and (per W-B6 decision) show logs of deleted books with a "Silinmiş kitap" placeholder so streak/calendar/detail agree. | `calendar_day_detail_screen.dart:61–105` | Read 30 min in an unfinished book → tap highlighted day → session listed |

---

## Phase 2 — Warnings

### 2A. Data integrity

| ID | Fix | Files / Anchor |
|---|---|---|
| T2.1 | **Audio pause discards segments.** Use `record` 5.x native `pause()`/`resume()` on the same recording instead of stop+new file. `recordingFilePath` stays constant across pauses. | `active_reading_vm.dart:125–147`, `audio_recording_service.dart` |
| T2.2 | **Edit log erases title.** Preserve `title` (and audit every field) in `_save`'s rebuilt `ReadingLog`; prefer `existing.copyWith(...)` now that T1.8 exists. | `edit_reading_log_screen.dart:199–209` |
| T2.3 | **`delete(id)` leaks media.** Delete audio file and note image like `deleteByBookId` does; extract shared `_deleteLogAssets(log)`. | `reading_logs_repository.dart:305–356` |
| T2.4 | **Single source of truth for repositories.** Make `booksRepositoryProvider`/`readingLogsRepositoryProvider` app-lifetime singletons; **never** `ref.invalidate` them (remove the shotgun invalidation block in `finish_reading_vm.dart:162–175`; notifiers reload from the singleton). Fix `reload()` to accept empty storage (remove `isNotEmpty` guard). Backup import calls `reload()` on the singletons after restore. Kills the lost-update / resurrection class. | `books_repository.dart:55–70`, `reading_logs_repository.dart:206–221`, `finish_reading_vm.dart`, `settings_screen.dart:326–329` |

### 2B. Time, streak & stats correctness

| ID | Fix | Files / Anchor |
|---|---|---|
| T2.5 | **DST-safe day math.** Replace all `add/subtract(Duration(days: n))` calendar stepping with `DateTime(y, m, d ± n)`. Audit: streak service, calendar widget, repositories. Add DST unit tests. | `streak_service.dart:21,35,62–71` |
| T2.6 | **Midnight boundary.** `hasCompletedReadingToday`: `!log.date.isBefore(todayStart)` in **both** repository implementations; extract shared helper. | `reading_logs_repository.dart:180–189, 359–364` |
| T2.7 | **Re-read accounting.** Move `readCount` increment to `markAsRead` (completing a re-read counts; abandoning doesn't). Add `Book.lastStartedAt` (set on `restartReading`); finish-flow prefill sums only logs after `lastStartedAt`. Requires model field + migration default (null → include all logs, current behavior). | `books_vm.dart:112,128–130`, `finish_reading_vm.dart:98–105`, `book.dart` |
| T2.8 | **Unit-safe durations.** Create `shared/utils/duration_format.dart`: single formatter taking `Duration`, with explicit `Duration`-producing helpers on `ReadingLog` (`effectiveDuration`). Fix: weekly chart uses seconds-based duration (sub-minute sessions visible), rename `pagesByDay`→`durationByDay`; detail screen "0 sn" (use `effectiveDurationSeconds`); day-detail `totalMinutes`-is-actually-seconds naming; timer display shows hours (`HH:MM:SS` past 60 min). | `reading_calendar_widget.dart:130–135`, `reading_log_detail_screen.dart:114,308–312`, `calendar_day_detail_screen.dart:58–72`, `active_reading_screen.dart:198–202` |
| T2.9 | **Day-detail page math.** Compute pages/day as `maxPageAtEnd(day) − maxPageAtEnd(before day)` (mirror profile screen's correct logic); extract shared helper used by both. | `calendar_day_detail_screen.dart:89–105`, `profile_screen.dart:55–69` |
| T2.10 | **Calendar/chart receive full logs.** Pass unfiltered logs to `ReadingCalendarWidget` and the weekly chart regardless of the stats period selector; only the aggregate cards use the period filter. | `profile_screen.dart:37–43, 360` |
| T2.11 | **Streak vs deleted books consistency.** Decision: logs of deleted books **count everywhere** (streak already does; app deliberately keeps logs). Calendar + day-detail include them (T1.12 placeholder covers UI). | `reading_calendar_widget.dart:123–126, 237–240` |
| T2.12 | **Recording duration wall-clock.** Derive `recordingDuration` from timestamps (accumulated-paused pattern already used for `elapsed`) instead of tick counting; re-sync in `syncTime()`. | `active_reading_vm.dart:174–183` |

### 2C. Crashes & UX-breaking

| ID | Fix | Files / Anchor |
|---|---|---|
| T2.13 | **Stale reading screen → duplicate logs.** After save: reset the active VM and replace the stack (`context.go(Routes.streak)` or pop until home before push) so back-nav cannot reach a stale ActiveReadingScreen with saved-but-live state. | `finish_reading_flow_screen.dart:229–231, 288–295` |
| T2.14 | **Double-tap add book.** `_isSaving` guard + disable button while saving (copy the pattern from finish flow). | `add_book_screen.dart:282–326, 786–790` |
| T2.15 | **Tab query param ignored.** Handle `?tab=` reactively (e.g. `GoRouterState.of(context)` in `build`/`didChangeDependencies`, or a router listener), not only in `initState`. | `home_screen.dart:38–50` |
| T2.16 | **Broken audio player copy.** Point-fix the inverted completion condition in the edit screen (align with detail screen's working version). Permanent fix = dedupe in T4.1. | `edit_reading_log_screen.dart:714–732` |
| T2.17 | **Empty-title revert loop.** Remove the build-time `_loadBookData` postFrameCallback; make "empty title" a validator error on save instead. | `edit_completed_book_screen.dart:230–234` |
| T2.18 | **Null-safe route extra.** `/calendar-day-detail`: cast `state.extra as Map<String,dynamic>?` and route to error screen on null (match `/finish` route's pattern). | `app_router.dart:142–147` |
| T2.19 | **Async-gap hygiene batch.** Add `mounted` checks / capture-before-await: add_book `_selectBook` (+ reentrancy guard so two fast taps can't mix title/cover), both `_loadAudio`s, edit-completed `_save`, edit_profile image pick (`Theme.of(context)` before await), home post-frame callback. Enable/heed `use_build_context_synchronously`. | `add_book_screen.dart:146–174`, `edit_reading_log_screen.dart:687–741`, `reading_log_detail_screen.dart:447–501`, `edit_completed_book_screen.dart:199–201`, `edit_profile_screen.dart:65–84` |
| T2.20 | **Controller leaks.** Dispose `_codeController` in DeleteBookDialog; hoist `FixedExtentScrollController` to State (create once, dispose, stop recreating per tick — also fixes fling snapping). | `delete_book_dialog.dart:17`, `finish_reading_flow_screen.dart:1253–1299` |
| T2.21 | **Watch state, not notifier.** Replace `ref.watch(booksVmProvider.notifier)` + `byId` with watching `booksVmProvider` state (or a family selector) in the three affected screens so late-loading data renders. | `book_reading_logs_screen.dart:50`, `reading_log_detail_screen.dart:28`, `edit_completed_book_screen.dart:15–18` |

### 2D. Platform, release & privacy (decision: app matches privacy claim)

| ID | Fix | Files / Anchor |
|---|---|---|
| T2.22 | **Fail release build without keystore.** Replace debug-signing fallback with `throw GradleException("key.properties missing — release builds must be signed")`. | `android/app/build.gradle.kts:53–58` |
| T2.23 | **Disable auto-backup.** `android:allowBackup="false"` + `android:fullBackupContent`/`dataExtractionRules` opting out; app's own export feature is the sanctioned backup path. | `AndroidManifest.xml:18` |
| T2.24 | **Remove `READ_MEDIA_AUDIO`.** Unused; recordings are app-private. | `AndroidManifest.xml:9` |
| T2.25 | **Bundle fonts.** Add Crimson Text (+ any other used families) TTFs to `assets/fonts/`, declare in pubspec, set `GoogleFonts.config.allowRuntimeFetching = false` (or drop google_fonts for plain `fontFamily`). App renders identically offline; no Google calls. | `app_theme.dart`, `pubspec.yaml` |
| T2.26 | **Notification startup hardening.** Wrap `tz.getLocation` in try/catch with UTC/`tz.local` fallback; never let `NotificationService.initialize()` failure block `runApp` (fire-and-forget with logging or guarded await). Fix DST first-fire: build next occurrence via calendar-day + `TZDateTime` components, not `add(Duration(days:1))`. Defer the POST_NOTIFICATIONS permission prompt from first frame to the moment the user enables reminders (default toggle OFF until consent). | `notification_service.dart:22–102`, `main.dart:30–32`, `notification_providers.dart:12,46` |
| T2.27 | **Make crash reporting real (minimal).** Persist last N errors to a local ring-buffer file (visible via settings "diagnostics" or at least retrievable), keep `return true`, remove debug-only gating. Alternative (if rejected): delete the service and stop pretending. | `crash_reporting_service.dart:23–41` |
| T2.28 | **Open Library UTF-8.** `json.decode(utf8.decode(response.bodyBytes))`; un-nest the double-wrapped exception. | `open_library_service.dart:121–143` |

---

## Phase 3 — Dead code & docs truth (decision: delete auth)

| ID | Fix | Files |
|---|---|---|
| T3.1 | Delete `features/auth/` entirely (login/register screens, `auth_service.dart`); remove any imports/references and the missing `assets/icons/google.png` usage. | `lib/features/auth/**` |
| T3.2 | Delete the dead `features/reading/presentation/streak_screen.dart` (hardcoded "1 Gün"). Router already uses the stats one. | `streak_screen.dart` (reading copy) |
| T3.3 | Delete `background_sync_service.dart` (all no-ops, zero call sites). | `shared/services/background_sync_service.dart` |
| T3.4 | Remove dead code batch: `_CongratsStep` + unreachable step-3 plumbing, `free_draggable.dart`, duplicate `/book-detail` route + duplicate router helper, `fetchPageCount`, `getRecordingDuration`, unused `filteredLogs`/`filterDate` params, `clearAll` (or keep with a caller in settings "reset"), `reset()` (fix to non-async-void if kept for T2.13). | various (see review) |
| T3.5 | **Docs truth pass.** README: remove/implement claims — "in-memory veri" → SharedPreferences; daily goals now real (T1.11); IMPLEMENTATION_SUMMARY: delete WorkManager/workmanager claims; unify branding to **Libris** everywhere (README, screens). | `README.md`, `IMPLEMENTATION_SUMMARY.md` |
| T3.6 | Version display: add `package_info_plus`, show real version in settings (replace hardcoded "1.0.2"). | `settings_screen.dart:364`, `pubspec.yaml` |
| T3.7 | Book header honesty: render real cover image (fallback icon only when missing) and real `book.category` instead of hardcoded "Klasikler". | `book_reading_logs_screen.dart:289–323` |

---

## Phase 4 — Refactors & polish (suggestions)

| ID | Fix | Files |
|---|---|---|
| T4.1 | Extract shared `AudioPlayerWidget` (single, working implementation) — replaces both ~270-line copies; edit screen's broken copy dies here permanently. | detail + edit reading-log screens → `shared/widgets/` |
| T4.2 | Extract shared image pick/crop bottom-sheet flow (5 duplicates). | finish flow ×2, edit log, add book, edit completed |
| T4.3 | Consolidate duration formatters onto T2.8's util (4 variants → 1); delete per-screen copies. Extract shared `_InfoCard`. | various |
| T4.4 | Merge `ImageStorageService` + `ProfileImageStorageService` into one parameterized service (byte-identical today). | `shared/services/` |
| T4.5 | Make `InMemoryReadingLogsRepository` truly in-memory (no `NoteStorageService` I/O) — it's the test double. | `reading_logs_repository.dart:18–190` |
| T4.6 | Input hardening: `FilteringTextInputFormatter.digitsOnly` on all numeric fields; clamp finish-flow page wheel to `>= book.currentPage`; sane bounds on hour/minute fields. | finish flow, edit log, add/edit book screens |
| T4.7 | Rebuild scoping: isolate timer text into its own `Consumer` (stop whole-screen rebuilds every second); stop rebuilding the finish-flow `PageView` on every keystroke (listen without watch, or select). | `active_reading_screen.dart:51`, `finish_reading_flow_screen.dart:121` |
| T4.8 | Barcode screen: `Color.fromARGB(80, 0, 0, 0)` overlay fix; await torch/camera toggles and reflect actual controller state. | `barcode_scanner_screen.dart:54–70, 102` |
| T4.9 | Backup hygiene: delete temp zip after share; (optional, note-only) streaming zip build for large media libraries. Remove unused `appDir` params. | `data_backup_service.dart:63–67, 83, 109` |
| T4.10 | Notes encoding: explicit `utf8` in `NoteStorageService`; distinguish decode-failure from missing note. | `note_storage_service.dart:33,46` |
| T4.11 | Permission service: per-permission dialog text (not always "ses kaydı"); remove legacy `Permission.storage` path; await `openAppSettings()`. | `permission_service.dart:35–58, 150–161` |
| T4.12 | Audio service hygiene: `cancelRecording` try/catch so `_isRecording` can't wedge; await `_recorder.dispose()`. | `audio_recording_service.dart:133–173` |
| T4.13 | VM load error handling: `books_vm`/`reading_providers` surface errors instead of eternal `isLoading`. | `books_vm.dart:28–31`, `reading_providers.dart:19–22` |
| T4.14 | Offline banner: don't flash "offline" during connectivity `loading`; simplify the double-StreamProvider construction; note the `results.first` arbitrariness. | `connectivity_service.dart:16–53`, `offline_banner.dart:11` |
| T4.15 | Copy fixes: "Tebrikler!" only when streak > 0; note-editor bold/italic buttons either persist formatting (markdown) or are removed. | `stats/streak_screen.dart:56`, `finish_reading_flow_screen.dart:998–1073` |
| T4.16 | (Optional, repo-level — outside app code) Move app out of nested `readlog-main/` to repo root; adopt conventional commit messages going forward. Requires user sign-off; not part of default execution. | repo root |

---

## Phase 5 — Test suite (fills the gaps that let these bugs ship)

| ID | Task | Covers |
|---|---|---|
| T5.1 | `FinishReadingVm` unit tests: minutes math (T1.1), direct-finish no-double-count (T1.2), prefill after restart (T2.7), `shouldShowStreak` midnight case (T2.6). | C1, C7, W-B2/B3 |
| T5.2 | `ActiveReadingVm` tests with fake clock + fake recorder: pause/resume elapsed math, wall-clock resync, recording duration (T2.12), pause keeps single file (T2.1). | C-adjacent timer logic |
| T5.3 | `reorderBooks` tests: down-drag adjustment, drop-at-end, invalid indices, single-save batching. | C8 |
| T5.4 | Storage/backup tests: malformed record fixtures (bad shelf/date/missing fields) skip-don't-throw (T1.3); corrupt blob → error state not empty (T1.4); import of invalid backup rejected atomically, prefs snapshot restored (T1.5); legacy `theme_mode` migration both types (T1.6). Replace the "can be instantiated" test. | C3, C4, C5 |
| T5.5 | `StreakService` DST/boundary tests (fixed-offset + DST timezone fixtures, midnight logs) added to the existing good suite. | W-B1/B2 |
| T5.6 | Rewrite `books_vm_test.dart`: cover mutating methods (`addBook`, `markAsRead`, `moveBookToShelf`, `updateBook` clearing fields via T1.8), remove the `Future.delayed(50ms)` flake pattern (await a load future / pump). Test `LocalBooksRepository`, not just the in-memory double. | multiple |
| T5.7 | Widget tests: add-book double-tap creates one book (T2.14); edit menu opens correct screen per shelf (T1.10); daily-goal screen on fresh profile (T1.11); calendar day-detail shows unfinished-book sessions (T1.12). | C6, C9, C10 |

---

## Phase X — Final Verification (definition of done)

1. `flutter analyze` → 0 issues.
2. `flutter test` → all green (including the new T0.3/T5.x suites).
3. `flutter build apk --release` **without** `key.properties` → fails with the explicit keystore message (T2.22); with keystore → succeeds.
4. Manual smoke on emulator/device:
   - [ ] Add book (double-tap save → one book), edit on every shelf, delete book.
   - [ ] Timed session with pause/resume + voice recording → single audio file, correct durations, one log; back-nav after save cannot re-save.
   - [ ] Finish a book with 1h30m manual entry → profile shows 90 min, not 90 h.
   - [ ] Streak/calendar/day-detail agree for unfinished books, midnight-dated logs, and a deleted book's logs.
   - [ ] Export → wipe → import round-trip preserves everything; importing a corrupted file is rejected with data untouched.
   - [ ] Theme set → export → import → relaunch: no crash, theme correct.
   - [ ] Airplane mode fresh launch: fonts correct, no network calls, no "offline" flash after reconnect.
   - [ ] Daily goal reachable from profile, no crash on fresh install, goal shown in progress UI.
   - [ ] Settings shows real version; no "1 Gün" fake streak screen reachable.
5. Grep gates: no `features/auth`, no `background_sync_service`, no `theme_mode` double-writer, no `getString('theme_mode')` outside ThemeManager/migration, no `subtract(const Duration(days:` in date-stepping code.
6. Mark this section `## ✅ PHASE X COMPLETE` with date + results.

---

## Dependency graph (summary)

```
T0.* ──► everything
T1.3 ──► T1.4 ──► T1.5        (safe parse → corrupt handling → import validation)
T1.8 ──► T2.2, T2.7, T5.6     (copyWith sentinels before field-clearing fixes)
T2.8 ──► T4.3                 (duration util before formatter dedupe)
T2.16 ─► T4.1                 (point-fix player, then dedupe)
T1.11 ─► T3.5                 (daily goal real before README claims it)
Phase 1–3 ──► Phase 4         (behavior correct before refactors)
All ──► Phase 5 finalization ─► Phase X
```
Parallel-safe: Group A/B/C/D/E within Phase 1 touch disjoint files and can be implemented in parallel; 2D (platform) is independent of 2A–2C.

## Rollback strategy

- One commit per task ID (`fix: T1.1 minutes-as-hours 60x inflation`), so any regression is a single `git revert`.
- Storage-format-touching tasks (T1.4, T1.6, T2.7) include forward-compatible migrations and keep `.bak` blobs; verified by round-trip tests before merging.
- Branch merges to `main` only after Phase X passes.

## Traceability

Every review finding maps to a task: criticals 1–10 → T1.1–T1.12 (+T0.3); warnings → T2.1–T2.28; suggestions/dead code/docs → T3.1–T3.7, T4.1–T4.16; test gaps → T5.1–T5.7. No finding was dropped; the only deferred item is T4.16 (repo restructure) pending explicit user sign-off.

---

## Execution status (branch `fix/code-review`, 2026-07-07)

**Done (committed, one commit per task):**
- **Phase 0** ✓ — baseline recorded ([docs/BASELINE-code-review.md](BASELINE-code-review.md)), branch, characterization tests.
- **Phase 1** ✓ — ALL criticals T1.1–T1.12, each with a regression test.
- **Phase 2** ✓ — ALL warnings T2.1–T2.28 (2A data-integrity, 2B time/stats, 2C crashes/UX, 2D platform/privacy).
- **Phase 3** ✓ (mostly) — T3.1/T3.2/T3.3 (auth + dead services deleted), T3.4 (dup route, dead filter mechanism, getRecordingDuration, fetchPageCount), T3.5 (docs/branding), T3.6 (real version), T3.7 (book header).

**Env notes / decisions taken autonomously:**
- **T2.25 fonts**: Crimson Text TTFs were not available to bundle and runtime
  fetching is forbidden by the privacy policy, so `google_fonts` was removed and
  the app uses the system font. To restore the serif look, add the TTFs under
  `assets/fonts/`, declare them in pubspec, and set `AppTheme._fontFamily`.
- `flutter analyze` needs `--no-pub` on this machine (or Windows Developer Mode)
  because plain analyze tries to build the plugin registrant (symlinks).

**Deferred (documented, not blocking):**
- **T3.4 remainder**: `_CongratsStep` (a now-unreachable PageView child — harmless)
  and `clearAll` (kept; no settings "reset" caller added).
- **Phase 4 (T4.1–T4.16 refactors/dedup)**: polish. The correctness underneath
  each was fixed. T4.3 partially done (`duration_format.dart` util exists; full
  per-screen formatter dedup pending). T4.16 (repo restructure) needs user sign-off.
- **Phase 5 (T5.1–T5.7)**: substantial regression tests were written inline with
  each fix (finish-vm, image storage, copyWith sentinels, safe-parse, corruption,
  backup import, reorder, daily-goal, calendar day-detail, streak DST, midnight
  boundary, re-read, reading-stats). Formal per-surface consolidation is the
  remaining gap; the critical coverage exists.

**Phase X verification:**
- `flutter analyze --no-pub` → **0 issues**.
- `flutter test` → **all green** (baseline was 105 pass / 33 fail; the 33 font
  failures are fixed by T2.25).
- Grep gates all pass (no `features/auth`, no `background_sync_service`, no
  `theme_mode` double-writer/stray reader, no `subtract(const Duration(days:`
  date-stepping, no `/book-detail`).
- **Release build (T2.22)**: could NOT be run to completion — the machine has a
  **malformed NDK** (`[CXX1101]` at `D:\tools\android-sdk\ndk\27.0.12077973`,
  missing `source.properties`) that fails Gradle configuration before the
  keystore gate can fire. Fix the NDK (delete that folder; let AGP re-download),
  then `flutter build apk --release` without `key.properties` should fail with
  "key.properties missing — release builds must be signed". The gate logic is
  verified by inspection of `android/app/build.gradle.kts`.
