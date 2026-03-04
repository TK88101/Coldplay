import SwiftUI
import ConfettiSwiftUI

struct ContentView: View {
    @Environment(AttendanceStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var toastMessage: String?
    @State private var confettiTrigger = 0
    @State private var showBackfill = false
    @State private var backfillDate = Date()
    @Namespace private var glassNS

    private var todayRecord: AttendanceRecord? {
        store.record(for: Date())
    }

    var body: some View {
        ZStack {
            // 渐变背景 — 给 Liquid Glass 提供色彩折射
            LinearGradient(
                colors: [.blue.opacity(0.15), .cyan.opacity(0.1), .green.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // 当前状态 — Liquid Glass 卡片
                statusCard
                    .padding(.bottom, 32)

                // 两个大按钮 — Liquid Glass interactive
                GlassEffectContainer(spacing: 24) {
                    HStack(spacing: 24) {
                        markButton(type: .work, tint: .blue, icon: "briefcase.fill")
                        markButton(type: .rest, tint: .green, icon: "leaf.fill")
                    }
                }
                .confettiCannon(trigger: $confettiTrigger, num: 30, radius: 300)

                // 补打按钮
                Button {
                    backfillDate = Date()
                    showBackfill = true
                } label: {
                    Label("补打卡", systemImage: "calendar.badge.plus")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 20)

                Spacer()

                // 累计统计 — Liquid Glass 底栏
                statsBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }

            // Toast 提示
            if let message = toastMessage {
                VStack {
                    Text(message)
                        .font(.subheadline.bold())
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .glassEffect(.regular, in: .capsule)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    Spacer()
                }
                .padding(.top, 60)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: toastMessage)
        .sheet(isPresented: $showBackfill) {
            backfillSheet
        }
    }

    // MARK: - 状态卡片

    @ViewBuilder
    private var statusCard: some View {
        if let record = todayRecord {
            VStack(spacing: 12) {
                Image(systemName: record.type == .work ? "briefcase.fill" : "leaf.fill")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(record.type == .work ? .blue : .green)
                    .symbolEffect(.breathe, isActive: !reduceMotion)

                Text(record.type.rawValue)
                    .font(.title2.bold())

                Text(Date(), format: .dateTime.month(.wide).day().weekday(.wide))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 28)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28))
        } else {
            VStack(spacing: 12) {
                Image(systemName: "clock")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(.secondary)

                Text("今天还没有打卡")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Text(Date(), format: .dateTime.month(.wide).day().weekday(.wide))
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 28)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28))
        }
    }

    // MARK: - 打卡按钮

    private func markButton(type: AttendanceType, tint: Color, icon: String) -> some View {
        Button {
            Task {
                let synced = await store.mark(type: type)
                withAnimation(.bouncy) {
                    confettiTrigger += 1
                }
                let label = type.rawValue
                toastMessage = synced ? "\(label) 已写入日历 ✓" : "\(label) 已记录"
                try? await Task.sleep(for: .seconds(2))
                toastMessage = nil
            }
        } label: {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 36, weight: .medium))
                Text(type.rawValue)
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(width: 130, height: 130)
        }
        .glassEffect(.regular.tint(tint).interactive(), in: RoundedRectangle(cornerRadius: 32))
    }

    // MARK: - 补打卡 Sheet

    private var backfillSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                DatePicker(
                    "选择日期",
                    selection: $backfillDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal)

                if let existing = store.record(for: backfillDate) {
                    Text("该日已标记：\(existing.type.rawValue)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 20) {
                    Button {
                        performBackfill(type: .work)
                    } label: {
                        Label("上班", systemImage: "briefcase.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .glassEffect(.regular.tint(.blue).interactive(), in: RoundedRectangle(cornerRadius: 16))

                    Button {
                        performBackfill(type: .rest)
                    } label: {
                        Label("休息", systemImage: "leaf.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .glassEffect(.regular.tint(.green).interactive(), in: RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .navigationTitle("补打卡")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showBackfill = false }
                }
            }
        }
    }

    private func performBackfill(type: AttendanceType) {
        Task {
            let synced = await store.mark(date: backfillDate, type: type)
            showBackfill = false
            withAnimation(.bouncy) {
                confettiTrigger += 1
            }
            let dateStr = backfillDate.formatted(.dateTime.month(.abbreviated).day())
            let label = type.rawValue
            toastMessage = synced ? "\(dateStr) \(label) 已写入日历 ✓" : "\(dateStr) \(label) 已记录"
            try? await Task.sleep(for: .seconds(2))
            toastMessage = nil
        }
    }

    // MARK: - 统计栏

    private var statsBar: some View {
        let stats = store.totalStats
        return HStack(spacing: 0) {
            statItem(label: "上班", value: "\(stats.workDays) 天", color: .blue)
            Spacer()
            Divider().frame(height: 28)
            Spacer()
            statItem(label: "休息", value: "\(stats.restDays) 天", color: .green)
            Spacer()
            Divider().frame(height: 28)
            Spacer()
            statItem(label: "工时", value: "\(Int(stats.totalHours))h", color: .primary)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
        .glassEffect(.regular, in: .capsule)
    }

    private func statItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
