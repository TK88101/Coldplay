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

**Data flow:** `ContentView` → `AttendanceStore` (singleton, `@Observable`) → `PersistenceService` (JSON) + `CalendarService` (EventKit)

- **AttendanceStore.shared** is the single source of truth, shared between UI and Siri Intents. Uses `yyyy-MM-dd` string keys for date deduplication (avoids timezone bugs with `Calendar.isDate(_:inSameDayAs:)`). Runs `deduplicate()` on init to clean historical data.
- **CalendarService** creates/manages a dedicated "考勤" calendar in EventKit. `syncRecord()` auto-requests calendar permission on first call — no separate permission flow needed. Prefers iCloud source for multi-device sync.
- **PersistenceService** handles JSON read/write with atomic writes and CSV export.
- **Siri Intents** (`MarkWorkIntent`, `MarkRestIntent`) go through `AttendanceStore.shared` directly. All Siri phrases in `AttendanceShortcuts` must contain `.applicationName` or the build fails.

**UI:** iOS 26 Liquid Glass design. `ContentView` is the only active view — `TodayView`, `CalendarView`, `StatsView` exist in the repo but are unused (legacy from earlier TabView design).

## Key Constraints

- **iOS 26.0 minimum** — uses `glassEffect()`, `GlassEffectContainer`, `symbolEffect(.breathe)` APIs
- **Free provisioning** — 7-day signing expiry, data persists in Documents directory across reinstalls
- **Chinese UI** — all user-facing strings are in Chinese (简体中文)
