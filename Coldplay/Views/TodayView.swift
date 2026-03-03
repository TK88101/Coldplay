import SwiftUI

struct TodayView: View {
    @Environment(AttendanceStore.self) private var store

    private var todayRecord: AttendanceRecord? {
        store.record(for: Date())
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // 日期显示
                Text(Date(), format: .dateTime.year().month(.wide).day().weekday(.wide))
                    .font(.title2)
                    .foregroundStyle(.secondary)

                Spacer()

                // 当前状态
                if let record = todayRecord {
                    statusView(record)
                } else {
                    Text("今天还没有打卡")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // 打卡按钮
                HStack(spacing: 24) {
                    markButton(type: .work, color: .blue, icon: "briefcase.fill")
                    markButton(type: .rest, color: .green, icon: "leaf.fill")
                }
                .padding(.bottom, 40)
            }
            .padding()
            .navigationTitle("考勤助手")
        }
    }

    private func statusView(_ record: AttendanceRecord) -> some View {
        VStack(spacing: 12) {
            Image(systemName: record.type == .work ? "briefcase.fill" : "leaf.fill")
                .font(.system(size: 60))
                .foregroundStyle(record.type == .work ? .blue : .green)

            Text("今日：\(record.type.rawValue)")
                .font(.title)
                .bold()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(record.type == .work ? Color.blue.opacity(0.1) : Color.green.opacity(0.1))
        )
    }

    private func markButton(type: AttendanceType, color: Color, icon: String) -> some View {
        Button {
            Task {
                await store.mark(type: type)
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 36))
                Text(type.rawValue)
                    .font(.headline)
            }
            .frame(width: 120, height: 120)
            .foregroundStyle(.white)
            .background(color, in: RoundedRectangle(cornerRadius: 20))
        }
        .shadow(color: color.opacity(0.3), radius: 8, y: 4)
    }
}
