import SwiftUI

struct CalendarView: View {
    @Environment(AttendanceStore.self) private var store
    @State private var displayedMonth = Date()

    private let calendar = Calendar.current
    private let weekdaySymbols = ["日", "一", "二", "三", "四", "五", "六"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                monthNavigator
                weekdayHeader
                daysGrid
                Spacer()
            }
            .padding()
            .navigationTitle("日历")
        }
    }

    // MARK: - Month navigator

    private var monthNavigator: some View {
        HStack {
            Button { changeMonth(by: -1) } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(displayedMonth, format: .dateTime.year().month(.wide))
                .font(.title2.bold())
            Spacer()
            Button { changeMonth(by: 1) } label: {
                Image(systemName: "chevron.right")
            }
        }
        .padding(.horizontal)
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var daysGrid: some View {
        let components = calendar.dateComponents([.year, .month], from: displayedMonth)
        let year = components.year!
        let month = components.month!
        let monthRecords = store.records(forYear: year, month: month)
        let firstDay = calendar.date(from: components)!
        let startWeekday = calendar.component(.weekday, from: firstDay)
        let daysInMonth = calendar.range(of: .day, in: .month, for: firstDay)!.count

        let totalSlots = startWeekday - 1 + daysInMonth
        let rows = (totalSlots + 6) / 7

        return VStack(spacing: 8) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { col in
                        let index = row * 7 + col
                        let day = index - (startWeekday - 1) + 1
                        if day >= 1 && day <= daysInMonth {
                            let date = calendar.date(from: DateComponents(year: year, month: month, day: day))!
                            dayCell(day: day, date: date, records: monthRecords)
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                    }
                }
            }
        }
    }

    private func dayCell(day: Int, date: Date, records: [AttendanceRecord]) -> some View {
        let record = records.first { calendar.isDate($0.date, inSameDayAs: date) }
        let isToday = calendar.isDateInToday(date)

        return VStack(spacing: 2) {
            Text("\(day)")
                .font(.body)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundStyle(isToday ? .white : .primary)
                .frame(width: 32, height: 32)
                .background {
                    if isToday {
                        Circle().fill(.blue)
                    }
                }

            // 考勤圆点
            Circle()
                .fill(dotColor(for: record))
                .frame(width: 6, height: 6)
                .opacity(record != nil ? 1 : 0)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
    }

    private func dotColor(for record: AttendanceRecord?) -> Color {
        switch record?.type {
        case .work: return .blue
        case .rest: return .green
        case .annualLeave: return .purple
        case .compensatoryRest: return .orange
        case nil: return .clear
        }
    }

    private func changeMonth(by value: Int) {
        if let newDate = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = newDate
        }
    }
}
