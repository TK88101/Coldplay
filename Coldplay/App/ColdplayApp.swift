import SwiftUI

@main
struct ColdplayApp: App {
    init() {
        NotificationService.scheduleDailyReminder()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(AttendanceStore.shared)
        }
    }
}
