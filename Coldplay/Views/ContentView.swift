import SwiftUI

struct ContentView: View {
    @Environment(AttendanceStore.self) private var store

    private var todayRecord: AttendanceRecord? {
        store.record(for: Date())
    }

    var body: some View {
        VStack(spacing: 48) {
            Spacer()

            // 当前状态
            if let record = todayRecord {
                VStack(spacing: 8) {
                    Image(systemName: record.type == .work ? "briefcase.fill" : "leaf.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(record.type == .work ? .blue : .green)
                    Text(record.type.rawValue)
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // 两个大按钮
            HStack(spacing: 32) {
                markButton(type: .work, color: .blue, icon: "briefcase.fill")
                markButton(type: .rest, color: .green, icon: "leaf.fill")
            }

            Spacer()
        }
    }

    private func markButton(type: AttendanceType, color: Color, icon: String) -> some View {
        Button {
            Task { await store.mark(type: type) }
        } label: {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 40))
                Text(type.rawValue)
                    .font(.title3.bold())
            }
            .frame(width: 140, height: 140)
            .foregroundStyle(.white)
            .background(color, in: RoundedRectangle(cornerRadius: 24))
        }
        .shadow(color: color.opacity(0.3), radius: 10, y: 5)
    }
}
