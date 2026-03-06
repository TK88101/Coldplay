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

- **AttendanceStore.shared** is the single source of truth, shared between UI and Siri Intents. Uses `yyyy-MM-dd` string keys for date deduplication (avoids timezone bugs with `Calendar.isDate(_:inSameDayAs:)`). Runs `deduplicate()` on init to clean historical data. `totalStats` uses fiscal year (Apr 1 – Mar 31) for stats. `availableYears` provides all recorded fiscal years for historical viewing. Overtime records stored separately in `overtime.json` (independent of daily attendance, same day can have both). Stats include `remainingLeave = max(0, (10 + overtimeDays) - annualLeaveDays - compensatoryRestDays)`.
- **CalendarService** creates/manages a dedicated "考勤" calendar in EventKit. `syncRecord()` auto-requests calendar permission on first call — no separate permission flow needed. Prefers iCloud source for multi-device sync. Overtime events write to user's existing "加班" calendar (not auto-created).
- **PersistenceService** handles JSON read/write with atomic writes. CSV auto-backup runs on every mark — saves per-month files (`attendance_YYYY-MM.csv`) to Documents directory (visible in Files app via `UIFileSharingEnabled`). Also provides full export via `exportCSV()`.
- **LocalizationManager.shared** manages app language (Traditional Chinese / Japanese). Uses `@Observable` + `UserDefaults` persistence. All UI strings go through this manager. Injected via `.environment()`.
- **Siri Intents** (`MarkWorkIntent`, `MarkRestIntent`) go through `AttendanceStore.shared` directly. All Siri phrases in `AttendanceShortcuts` must contain `.applicationName` or the build fails.

**UI:** iOS 26 Liquid Glass design. `ContentView` is the main view with five capsule action buttons (work/overtime/rest/annual leave/backfill), status card, and stats bar (work days with overtime count / remaining leave / overtime days / rest days). Rest button shows confirmation dialog: "正常休息" or "還休（扣加班）". Backfill sheet has 2x2 grid (work/rest/annual leave/compensatory rest). `SettingsView` provides language switching and CSV export. `TodayView`, `CalendarView`, `StatsView` exist in the repo but are unused (legacy from earlier TabView design).

## Key Constraints

- **iOS 26.0 minimum** — uses `glassEffect()`, `GlassEffectContainer`, `symbolEffect(.breathe)` APIs
- **Free provisioning** — 7-day signing expiry, no iCloud entitlement available. Data persists in Documents directory across reinstalls. SideStore handles auto-resign.
- **SideStore distribution** — Install via iloader (Mac) → SideStore (iPhone). AltStore is NOT needed. AltStore Source JSON at `distribution/source.json`, IPA hosted on GitHub Releases. GitHub repo must be **public** for URLs to work. iloader "Import IPA" can also directly install .ipa via USB.
- **Multi-language UI** — supports Traditional Chinese (繁體中文) and Japanese (日本語), switchable in Settings. `LocalizationManager` handles all UI strings; `AppLanguage.locale` controls date formatting.
- **Attendance types** — `AttendanceType` enum: `.work`(上班), `.rest`(休息), `.annualLeave`(年假), `.compensatoryRest`(補休). Overtime is a separate `OvertimeRecord` model (independent of daily attendance). Compensatory rest deducts from available leave (10 base + overtime days).
- **Fiscal year reset** — `totalStats` uses fiscal year Apr 1 – Mar 31 (not calendar year). 10 days annual leave per fiscal year. `remainingLeave` = 10 + overtimeDays - annualLeaveDays - compensatoryRestDays. Historical fiscal years viewable via tapping stats bar.
- **CSV auto-backup** — every mark triggers `autoBackup()` saving per-month CSV to Documents. Files visible in iOS Files app under "Coldplay".
- **App icon** — Gemini AI-generated design: frosted glass calendar card with blue (work) / green (rest) dots on blue→green gradient background. 1024x1024 RGB PNG, no alpha. Located at `Coldplay/Assets.xcassets/AppIcon.appiconset/AppIcon.png`.
