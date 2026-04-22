# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

This project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the Xcode project from `project.yml`. After any change to project structure (adding/removing files, changing dependencies), regenerate:

```bash
xcodegen generate
```

**Build for simulator:**
```bash
xcodebuild -scheme Coldplay -sdk iphonesimulator26.2 SYMROOT=/tmp/ColdplayBuild build
```

**Build for device (requires Xcode GUI for signing credentials):**
```bash
xcodebuild -scheme Coldplay -sdk iphoneos26.2 SYMROOT=/tmp/ColdplayBuild -allowProvisioningUpdates build
```

**Run all tests:**
```bash
xcodebuild -scheme Coldplay -sdk iphonesimulator26.2 SYMROOT=/tmp/ColdplayBuild \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

> Always use `SYMROOT=/tmp/ColdplayBuild` — the project lives in an iCloud-synced directory, and building in-place causes extended attribute errors.

> Always use `-scheme Coldplay` (not `-target`) because the ConfettiSwiftUI SPM dependency requires scheme-based builds.

## Architecture

Lightweight MVVM + Service Layer. Single-screen attendance tracking app.

**Data flow:** `ContentView` → `AttendanceStore` (singleton, `@Observable`) → `PersistenceService` (JSON + CSV) + `CalendarService` (EventKit)

- **AttendanceStore.shared** is the single source of truth, shared between UI and Siri Intents. Uses `yyyy-MM-dd` string keys for date deduplication (avoids timezone bugs with `Calendar.isDate(_:inSameDayAs:)`). Runs `deduplicate()` on init to clean historical data. `totalStats` uses fiscal year (Apr 1 – Mar 31) for stats. `availableYears` provides all recorded fiscal years for historical viewing. Overtime records stored separately in `overtime.json` (independent of daily attendance, same day can have both). Stats include `remainingLeave = max(0, (10 + overtimeDays) - annualLeaveDays - compensatoryRestDays)`. `markOvertime(replaceExisting:)` supports an optional replace mode that clears same-day overtime records and calendar events before appending. Query APIs `hasOvertime(on:)` / `overtimeHours(on:)` power the same-day confirmation dialog. `reconcileOvertimeWithCalendar()` scans overtime records with a stored `calendarEventID` and removes any whose calendar event has been deleted externally (Calendar.app) — returns count of orphans removed. Legacy records without `calendarEventID` are intentionally left alone to avoid false deletions.
- **NotificationService.shared** (@MainActor singleton) wraps `UNUserNotificationCenter` for the daily 12:00 attendance reminder. `requestPermission()` requests `.alert`/`.sound` authorization. `checkDenied()` (async) detects `.denied` status. `scheduleReminder()` creates a repeating `UNCalendarNotificationTrigger` at 12:00 with identifier `"coldplay.attendance.reminder"`. `cancelReminder()` removes pending requests. `evaluateReminder(hasTodayRecord:)` orchestrates schedule/cancel based on `reminderEnabled` (UserDefaults, default true) and whether today has a record — when today is handled, calls `rescheduleForNextDay()` (before noon: one-shot trigger for tomorrow; after noon: repeating trigger resumes from tomorrow). `ContentView.task` requests permission at launch only if `reminderEnabled`; `.onChange(of: scenePhase)` re-evaluates on `.active`. `AttendanceStore.mark()` calls `evaluateReminder(hasTodayRecord: true)` only when `isDateInToday` (backfilling history dates does not affect today's reminder; Siri Intents covered automatically via shared store). `SettingsView` has a toggle backed by `reminderEnabled`.
- **CalendarService** creates/manages a dedicated "考勤" calendar in EventKit. Uses `var store = EKEventStore()` — reinitializes after permission grant to ensure sources load. `ContentView.task` requests permission at launch; if denied, shows alert with "前往設定" button (`UIApplication.openSettingsURLString`). `isDenied` property detects `.denied`/`.restricted` status. Prefers iCloud source for multi-device sync, with multi-layer fallback (iCloud → local → CalDAV → default → any source). Overtime events write to user's existing "加班" calendar (not auto-created). Annual leave writes to user's existing "年假" calendar (not auto-created). On type change, all related calendars (考勤 + 年假) are cleaned for that day before writing new event. `syncOvertime` returns the created event's `eventIdentifier` (nil on failure) so the store can persist it on the matching `OvertimeRecord`. `removeOvertimeEvents(on:)` purges all overtime events on a given day (used by replace mode). `overtimeEventExists(eventID:)` wraps `store.event(withIdentifier:)` for the reconcile path; when access is denied it returns `true` (treat as unknown — do not remove local data).
- **PersistenceService** handles JSON read/write with atomic writes. CSV auto-backup runs on every mark — saves per-month files (`attendance_YYYY-MM.csv`) to Documents directory (visible in Files app via `UIFileSharingEnabled`). Also provides full export via `exportCSV()`.
- **LocalizationManager.shared** manages app language (Traditional Chinese / Japanese). Uses `@Observable` + `UserDefaults` persistence. All UI strings go through this manager. Injected via `.environment()`.
- **Siri Intents** (`MarkWorkIntent`, `MarkRestIntent`) go through `AttendanceStore.shared` directly. All Siri phrases in `AttendanceShortcuts` must contain `.applicationName` or the build fails.

**UI:** iOS 26 Liquid Glass design. `ContentView` is the main view with five capsule action buttons (work/overtime/rest/annual leave/backfill), status card, and stats bar (work days / overtime days / rest days / remaining leave). Rest button shows confirmation dialog: "正常休息" or "還休（扣加班）". When overtime is punched on a day that already has an overtime record, a confirmation dialog with "取代 / 累加 / 取消" is shown (pendingOvertime state carries the punch parameters + a `fromBackfill` flag so the shared `commitOvertime(...)` helper can route either path). Backfill sheet has five vertical buttons matching main interface order (work/overtime/rest/annual leave/compensatory rest), with overtime opening a time picker sub-sheet. On launch (`.task`) and on resume (`scenePhase == .active`), `ContentView` calls `reconcileOvertimeAndNotify()` which invokes `store.reconcileOvertimeWithCalendar()` and surfaces a toast if any orphan records were removed. `SettingsView` provides reminder toggle, language switching, and CSV export. `TodayView`, `CalendarView`, `StatsView` exist in the repo but are unused (legacy from earlier TabView design).

## Key Constraints

- **iOS 26.0 minimum** — uses `glassEffect()`, `GlassEffectContainer`, `symbolEffect(.breathe)` APIs
- **Free provisioning** — 7-day signing expiry, no iCloud entitlement available. Data persists in Documents directory across reinstalls. SideStore handles auto-resign.
- **SideStore distribution** — Install via iloader (Mac) → SideStore (iPhone). AltStore is NOT needed. AltStore Source JSON at `distribution/source.json`, IPA hosted on GitHub Releases. GitHub repo must be **public** for URLs to work. iloader "Import IPA" can also directly install .ipa via USB.
- **Multi-language UI** — supports Traditional Chinese (繁體中文) and Japanese (日本語), switchable in Settings. `LocalizationManager` handles all UI strings; `AppLanguage.locale` controls date formatting.
- **Attendance types** — `AttendanceType` enum: `.work`(上班), `.rest`(休息), `.annualLeave`(年假), `.compensatoryRest`(補休). Overtime is a separate `OvertimeRecord` model (independent of daily attendance). Compensatory rest deducts from available leave (10 base + overtime days).
- **Fiscal year reset** — `totalStats` uses fiscal year Apr 1 – Mar 31 (not calendar year). 10 days annual leave per fiscal year. `remainingLeave` = 10 + overtimeDays - annualLeaveDays - compensatoryRestDays. Historical fiscal years viewable via tapping stats bar.
- **CSV auto-backup** — every mark triggers `autoBackup()` saving per-month CSV to Documents. Files visible in iOS Files app under "Coldplay".
- **App icon** — Gemini AI-generated design: frosted glass calendar card with blue (work) / green (rest) dots on blue→green gradient background. 1024x1024 RGB PNG, no alpha. Located at `Coldplay/Assets.xcassets/AppIcon.appiconset/AppIcon.png`.
