import SwiftUI

@main
struct ColdplayApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(AttendanceStore.shared)
        }
    }
}
