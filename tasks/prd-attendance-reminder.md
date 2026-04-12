# PRD: Daily Attendance Reminder

## Introduction

Add a smart daily reminder that notifies users at 12:00 to clock in, but only if they haven't recorded any attendance for the day yet. This prevents unnecessary notifications on days the user has already handled, while catching forgotten clock-ins before the workday ends.

## Goals

- Remind users to clock in at 12:00 daily via iOS local notification
- Automatically skip the reminder if the user has already recorded any attendance type for the day
- Follow the existing permission handling pattern (detect denied state, guide user to Settings)
- Keep the implementation minimal (fixed 12:00 time) with a path to user-customizable time in the future

## User Stories

### US-001: Schedule daily attendance check notification
**Description:** As a user, I want to receive a local notification at 12:00 each day reminding me to clock in, so that I don't forget to record my attendance.

**Acceptance Criteria:**
- [x] App schedules a repeating daily local notification at 12:00
- [x] Notification title and body use localized strings (Traditional Chinese / Japanese)
- [x] Notification is scheduled on app launch and re-scheduled when app returns to foreground
- [x] Tapping the notification opens the app to the main screen
- [x] Build succeeds with `xcodebuild -scheme Coldplay -sdk iphonesimulator26.2 SYMROOT=/tmp/ColdplayBuild build`

### US-002: Suppress reminder when already clocked in
**Description:** As a user, I don't want to be bothered with a reminder on days I've already clocked in, so that notifications stay relevant and non-intrusive.

**Acceptance Criteria:**
- [x] Before the notification fires, the app checks if any attendance record exists for today (`.work`, `.rest`, `.annualLeave`, `.compensatoryRest`)
- [x] If a record exists, the pending notification for today is removed/not delivered
- [x] Check runs on every attendance mark action (so marking at 10:00 cancels the 12:00 reminder)
- [x] Check also runs on app launch and foreground resume
- [x] If user deletes today's record (via backfill/overwrite), the reminder is re-scheduled for the next day cycle
- [x] Build succeeds

### US-003: Request notification permission
**Description:** As a user, I want the app to ask for notification permission so that reminders can reach me even when the app is in the background.

**Acceptance Criteria:**
- [x] App requests notification permission (`UNUserNotificationCenter.requestAuthorization`) on first launch
- [x] Permission request happens alongside the existing calendar permission request in `ContentView.task`
- [x] If permission is already granted, no prompt is shown
- [x] Build succeeds

### US-004: Handle denied notification permission
**Description:** As a user who denied notification permission, I want to be guided to enable it in Settings, following the same pattern as the calendar permission alert.

**Acceptance Criteria:**
- [x] App detects when notification permission is `.denied`
- [x] Shows an alert with localized message explaining why notifications are needed
- [x] Alert includes a button that opens iOS Settings (`UIApplication.openSettingsURLString`)
- [x] Alert is shown in the same manner as the existing calendar permission denied alert
- [x] Permission status is re-checked on `scenePhase` change to `.active`
- [x] Localized strings added for both Traditional Chinese and Japanese
- [x] Build succeeds

### US-005: Integrate reminder toggle in Settings
**Description:** As a user, I want a toggle in the Settings view to enable/disable the attendance reminder, so I have control over notifications.

**Acceptance Criteria:**
- [x] New toggle in `SettingsView`: "Attendance Reminder" (localized)
- [x] Toggle state persisted via `UserDefaults`
- [x] Default value: enabled (true)
- [x] When disabled, all pending attendance reminder notifications are cancelled
- [x] When re-enabled, notification is re-scheduled (if not already clocked in today)
- [x] Localized label for both Traditional Chinese and Japanese
- [x] Build succeeds

## Functional Requirements

- FR-1: Use `UNUserNotificationCenter` to schedule a daily repeating notification at 12:00 local time
- FR-2: Notification content must use `LocalizationManager` for title and body strings
- FR-3: On every attendance mark (`AttendanceStore.mark()`), cancel the pending notification via `NotificationService.shared.cancelReminder()`
- FR-4: On app launch (`ContentView.task`) and foreground resume (`scenePhase == .active`), call `evaluateReminder(hasTodayRecord:)` to schedule or cancel
- FR-5: Request `UNUserNotificationCenter.requestAuthorization(options: [.alert, .sound])` during the existing permission flow in `ContentView.task`
- FR-6: Detect `.denied` notification permission status via `NotificationService.shared.checkDenied()` and present a Settings redirect alert
- FR-7: Provide a "reminder enabled" toggle in `SettingsView`, persisted via `UserDefaults` key `attendanceReminderEnabled`, default `true`
- FR-8: When the toggle is off, call `cancelReminder()` to remove all pending notification requests
- FR-9: Fixed notification identifier: `"coldplay.attendance.reminder"`
- FR-10: Today's record check uses `AttendanceStore.shared.record(for: Date()) != nil` (any `AttendanceType` counts; overtime alone does NOT suppress)

## Non-Goals

- No customizable reminder time (future enhancement, not this version)
- No multiple reminders per day
- No notification actions/buttons (just tap to open app)
- No reminder for overtime specifically
- No push notifications or server-side logic
- No widget or Live Activity integration

## Design Considerations

- Follow existing Liquid Glass UI style for the Settings toggle
- Permission denied alert should match the existing calendar permission alert layout and copy style
- No new views needed beyond the Settings toggle row

## Technical Considerations

- `NotificationService` (@MainActor singleton) encapsulates all `UNUserNotificationCenter` logic, mirroring `CalendarService` pattern
- `UNCalendarNotificationTrigger` with `DateComponents(hour: 12, minute: 0)` and `repeats: true`
- On attendance mark: `cancelReminder()` removes the repeating trigger; on next foreground resume `evaluateReminder()` re-schedules if needed
- Siri Intents go through `AttendanceStore.shared`, so `cancelReminder()` in `mark()` automatically covers Siri-triggered attendance
- No `Info.plist` / `project.yml` changes needed — local notification capability doesn't require a special entitlement

## Success Metrics

- Users who forget to clock in receive the 12:00 reminder and can act on it
- Users who clock in before 12:00 never see the reminder (zero false-positive notifications)
- Notification permission grant rate tracked implicitly (reminder functions when granted)

## Open Questions

- ~~Should the reminder also check overtime records?~~ **Resolved:** Only `AttendanceType` records suppress the reminder; overtime alone does NOT suppress it since overtime is independent of daily attendance.
- When user-customizable time is added later, should it support multiple reminder times or just one?
