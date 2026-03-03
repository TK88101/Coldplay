import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem {
                    Label("今日", systemImage: "checkmark.circle.fill")
                }

            CalendarView()
                .tabItem {
                    Label("日历", systemImage: "calendar")
                }

            StatsView()
                .tabItem {
                    Label("统计", systemImage: "chart.bar.fill")
                }
        }
    }
}
