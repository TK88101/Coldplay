import SwiftUI

struct ContentView: View {
    @Environment(AttendanceStore.self) private var store
    @State private var toastMessage: String?

    private var todayRecord: AttendanceRecord? {
        store.record(for: Date())
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
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

                // 累计统计
                let stats = store.totalStats
                HStack(spacing: 32) {
                    statItem(label: "上班", value: "\(stats.workDays) 天", color: .blue)
                    statItem(label: "休息", value: "\(stats.restDays) 天", color: .green)
                    statItem(label: "工时", value: "\(Int(stats.totalHours))h", color: .primary)
                }
                .padding(.bottom, 40)
            }

            // Toast 提示
            if let message = toastMessage {
                VStack {
                    Text(message)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(.black.opacity(0.75), in: Capsule())
                        .transition(.move(edge: .top).combined(with: .opacity))
                    Spacer()
                }
                .padding(.top, 60)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: toastMessage)
    }

    private func markButton(type: AttendanceType, color: Color, icon: String) -> some View {
        Button {
            Task {
                let synced = await store.mark(type: type)
                let label = type.rawValue
                toastMessage = synced ? "\(label) 已写入日历 ✓" : "\(label) 已记录（日历未同步）"
                try? await Task.sleep(for: .seconds(2))
                toastMessage = nil
            }
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

    private func statItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
