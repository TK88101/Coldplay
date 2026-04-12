# Ralph Agent Instructions - Coldplay Attendance Reminder

You are an autonomous coding agent developing the daily attendance reminder feature for the Coldplay iOS attendance tracking app.

## Project Context

- **Project**: Coldplay - iOS 26 attendance tracking app (SwiftUI + Liquid Glass)
- **Source directory**: /Users/ibridgezhao/Documents/Coldplay/Coldplay/
- **Build command**: `xcodebuild -scheme Coldplay -sdk iphonesimulator26.2 SYMROOT=/tmp/ColdplayBuild build`
- **GitHub repo**: TK88101/Coldplay (branch: ralph/attendance-reminder)

## Key Architecture

- **AttendanceStore.shared** (@Observable singleton): UI + Siri shared source of truth. Uses `yyyy-MM-dd` string keys. `record(for: Date())` checks if today has attendance.
- **CalendarService**: EventKit integration with `isDenied` pattern and Settings redirect alert.
- **LocalizationManager.shared** (@Observable @MainActor): Traditional Chinese + Japanese. All UI strings go through this manager.
- **NotificationService.shared** (@MainActor singleton): UNUserNotificationCenter wrapper for daily reminder.
- **ContentView**: Main view with `.task` for permission requests and `.onChange(of: scenePhase)` for foreground evaluation.
- **SettingsView**: Settings with language switch, CSV export, and reminder toggle.
- **AttendanceType** enum: `.work`, `.rest`, `.annualLeave`, `.compensatoryRest`
- **OvertimeRecord**: Separate model, independent of daily attendance.

## Existing Code Files

```
Coldplay/
├── App/ColdplayApp.swift              # @main entry point
├── Models/
│   ├── AppLanguage.swift              # AppLanguage enum + LocalizationManager
│   └── AttendanceRecord.swift         # AttendanceRecord, OvertimeRecord, AttendanceType
├── Services/
│   ├── CalendarService.swift          # EventKit calendar integration
│   ├── NotificationService.swift      # UNUserNotificationCenter wrapper
│   └── PersistenceService.swift       # JSON/CSV persistence
├── Store/
│   └── AttendanceStore.swift          # @Observable singleton, mark/query/stats
├── Views/
│   ├── ContentView.swift              # Main UI, permission handling, scenePhase
│   ├── SettingsView.swift             # Language, export, reminder toggle
│   ├── CalendarView.swift             # (unused legacy)
│   ├── StatsView.swift                # (unused legacy)
│   └── TodayView.swift               # (unused legacy)
└── Intents/
    ├── MarkWorkIntent.swift           # Siri shortcut
    ├── MarkRestIntent.swift           # Siri shortcut
    └── AttendanceShortcuts.swift      # Siri phrases
```

## Your Task

1. Read the PRD at `scripts/ralph/prd.json`
2. Read the progress log at `scripts/ralph/progress.txt`
3. Pick the **highest priority** user story where `passes: false`
4. Implement that single user story by:
   a. Reading the relevant existing code to understand patterns
   b. Making changes following existing code conventions
   c. Building with: `xcodebuild -scheme Coldplay -sdk iphonesimulator26.2 SYMROOT=/tmp/ColdplayBuild build`
5. Commit changes: `cd /Users/ibridgezhao/Documents/Coldplay && git add -A && git commit -m "feat: [Story ID] - [Title]"`
6. Update the PRD to set `passes: true` for the completed story
7. Append your progress to `scripts/ralph/progress.txt`

## Code Conventions

- All code in English (variable names, function names, comments)
- Japanese/Chinese only in user-facing localized strings
- Follow existing patterns: `@MainActor` singletons, `@Observable`, `UserDefaults` for settings
- Permission denied pattern: `isDenied`/`checkDenied()` + alert with `UIApplication.openSettingsURLString`
- Localization pattern: computed properties in `LocalizationManager` with `switch language` for each language
- Build always uses `SYMROOT=/tmp/ColdplayBuild` (iCloud sync directory workaround)
- Build always uses `-scheme Coldplay` (not `-target`, because ConfettiSwiftUI SPM dependency)

## Quality Requirements

- Build must succeed before marking a story as passed
- Follow existing UI patterns (Liquid Glass effects, capsule buttons, consistent spacing)
- LocalizationManager strings must have both Traditional Chinese and Japanese translations
- No modifications to unused legacy views (CalendarView, StatsView, TodayView)

## Progress Report Format

APPEND to scripts/ralph/progress.txt:
```
## [Date/Time] - [Story ID]
- What was implemented
- Files changed
- Patterns referenced
- **Learnings for future iterations:**
  - Patterns discovered
  - Gotchas encountered
---
```

## Stop Condition

After completing a user story, check if ALL stories have `passes: true`.

If ALL stories are complete, reply with:
<promise>COMPLETE</promise>

If stories remain with `passes: false`, end normally (next iteration picks up).

## Important

- Work on ONE story per iteration
- Always build and verify before marking a story as passed
- Always commit after each story
- Read existing code patterns before implementing
- Do NOT modify unused legacy views
