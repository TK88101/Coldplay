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

- **AttendanceStore.shared** is the single source of truth, shared between UI and Siri Intents. Uses `yyyy-MM-dd` string keys for date deduplication (avoids timezone bugs with `Calendar.isDate(_:inSameDayAs:)`). Runs `deduplicate()` on init to clean historical data. `totalStats` only counts current year (resets Jan 1). `availableYears` provides all recorded years for historical viewing.
- **CalendarService** creates/manages a dedicated "考勤" calendar in EventKit. `syncRecord()` auto-requests calendar permission on first call — no separate permission flow needed. Prefers iCloud source for multi-device sync.
- **PersistenceService** handles JSON read/write with atomic writes. CSV auto-backup runs on every mark — saves per-month files (`attendance_YYYY-MM.csv`) to Documents directory (visible in Files app via `UIFileSharingEnabled`). Also provides full export via `exportCSV()`.
- **LocalizationManager.shared** manages app language (Traditional Chinese / Japanese). Uses `@Observable` + `UserDefaults` persistence. All UI strings go through this manager. Injected via `.environment()`.
- **Siri Intents** (`MarkWorkIntent`, `MarkRestIntent`) go through `AttendanceStore.shared` directly. All Siri phrases in `AttendanceShortcuts` must contain `.applicationName` or the build fails.

**UI:** iOS 26 Liquid Glass design. `ContentView` is the main view with three capsule action buttons (work/rest/backfill), status card, and stats bar. `SettingsView` provides language switching and CSV export. `TodayView`, `CalendarView`, `StatsView` exist in the repo but are unused (legacy from earlier TabView design).

## Key Constraints

- **iOS 26.0 minimum** — uses `glassEffect()`, `GlassEffectContainer`, `symbolEffect(.breathe)` APIs
- **Free provisioning** — 7-day signing expiry, no iCloud entitlement available. Data persists in Documents directory across reinstalls. SideStore can be used for auto-resign.
- **Multi-language UI** — supports Traditional Chinese (繁體中文) and Japanese (日本語), switchable in Settings. `LocalizationManager` handles all UI strings; `AppLanguage.locale` controls date formatting.
- **Annual stats reset** — `totalStats` resets on Jan 1 each year. Historical years viewable via tapping stats bar.
- **CSV auto-backup** — every mark triggers `autoBackup()` saving per-month CSV to Documents. Files visible in iOS Files app under "Coldplay".
