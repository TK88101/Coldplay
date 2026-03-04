# Coldplay — 考勤助手 PRD

## 产品概述

Coldplay 是一款极简 iOS 考勤打卡应用，专为不固定休息日的工作模式设计。用户每天只需点击一个按钮即可标记"上班"或"休息"，记录自动同步到 iPhone 原生日历，方便查看累计工作天数和休息天数。

## 目标用户

- 不固定休息日的工作者（如服务业、排班制）
- 需要简单记录出勤情况的个人用户
- 希望在 iPhone 日历中查看工作/休息安排的用户

## 核心功能

### 1. 每日快速打卡

| 项目 | 说明 |
|------|------|
| 操作方式 | 主屏两个大按钮："上班"(蓝色) / "休息"(绿色) |
| 同一天逻辑 | 同一天多次点击只保留最后一次（替换而非累加） |
| 反馈 | 成功后弹出 Confetti 纸花特效 + Toast 提示 |
| 状态展示 | 卡片显示今日已打卡状态（图标 + 类型 + 日期） |

### 2. 补打卡

| 项目 | 说明 |
|------|------|
| 入口 | 主屏"补打卡"按钮 |
| 交互 | 弹出 Sheet，含图形化日期选择器（仅可选今天及之前） |
| 提示 | 如果所选日期已有记录，显示当前标记状态 |
| 确认 | 选择"上班"或"休息"后自动写入并关闭 |

### 3. 日历同步

| 项目 | 说明 |
|------|------|
| 日历名称 | "考勤"（专用日历，自动创建） |
| 上班事件 | 时间段事件，默认 12:00-20:00（JST） |
| 休息事件 | 全天事件 |
| 同步来源 | 优先 iCloud，其次本地日历 |
| 防重复 | 重新标记时先删除旧事件再创建新事件 |
| 权限 | 首次使用自动请求日历权限，权限被拒时仍可本地记录 |

### 4. 累计统计

| 项目 | 说明 |
|------|------|
| 展示位置 | 主屏底部玻璃胶囊栏 |
| 统计项 | 累计上班天数、累计休息天数、累计工时 |
| 工时计算 | 每个工作日固定 8 小时 |
| 月度查询 | 支持按年月筛选统计 |

### 5. 每日提醒

| 项目 | 说明 |
|------|------|
| 触发时间 | 每天 12:00（设备本地时区，即 JST） |
| 内容 | "今天上班吗？" |
| 目的 | 防止用户忘记打卡 |

### 6. Siri 语音快捷指令

| 指令 | 短语示例 |
|------|----------|
| 记录上班 | "用 Coldplay 记录上班"、"在 Coldplay 打卡上班" |
| 记录休息 | "用 Coldplay 记录休息"、"在 Coldplay 打卡休息" |

### 7. CSV 导出

| 项目 | 说明 |
|------|------|
| 格式 | CSV（日期, 类型, 上班时间, 下班时间, 备注） |
| 分享 | 通过系统分享功能发送 |

## 技术架构

### 技术栈

| 项目 | 选型 |
|------|------|
| 语言 | Swift 5.9 |
| 框架 | SwiftUI |
| 最低版本 | iOS 26.0 |
| 日历 | EventKit |
| 语音 | App Intents |
| 通知 | UserNotifications |
| 存储 | 本地 JSON（Documents 目录） |
| 动画 | ConfettiSwiftUI (SPM) |
| UI 风格 | iOS 26 Liquid Glass |
| 项目管理 | XcodeGen (project.yml) |
| 分发 | Xcode 免费签名 Sideload |

### 架构模式

轻量 MVVM + Service Layer：

```
App/                    → 应用入口
Models/                 → 数据模型 (AttendanceRecord)
Services/
  PersistenceService    → JSON 读写 + CSV 导出
  CalendarService       → EventKit 封装（日历创建/事件管理）
  NotificationService   → 每日提醒调度
Store/
  AttendanceStore       → @Observable 单例，核心业务逻辑
Views/
  ContentView           → 主界面（Liquid Glass 风格）
Intents/
  MarkWorkIntent        → Siri "记录上班"
  MarkRestIntent        → Siri "记录休息"
  AttendanceShortcuts   → 短语注册
```

### 数据模型

```swift
enum AttendanceType: String, Codable, CaseIterable {
    case work = "上班"
    case rest = "休息"
}

struct AttendanceRecord: Codable, Identifiable {
    let id: UUID
    let date: Date              // 哪一天（标准化到 startOfDay）
    let type: AttendanceType    // 上班 or 休息
    let startTime: Date?        // 上班时间（仅工作日，可选）
    let endTime: Date?          // 下班时间（仅工作日，可选）
    let note: String?           // 备注
    let createdAt: Date         // 创建时间
}
```

### 关键设计决策

| 决策 | 原因 |
|------|------|
| `yyyy-MM-dd` 字符串去重 | 比 `Calendar.isDate(_:inSameDayAs:)` 更可靠，避免时区陷阱 |
| 启动时 `deduplicate()` | 清理历史中可能存在的同一天重复记录 |
| CalendarService 自动请求权限 | `syncRecord()` 内部检查并按需请求，无需手动触发 |
| 单例 `AttendanceStore.shared` | Siri Intent 和 UI 共享同一份数据 |
| JSON 原子写入 | `.atomic` 选项防止写入中断导致数据损坏 |

## UI 设计

### 视觉风格

采用 iOS 26 Liquid Glass 设计语言：

- **背景**: 蓝/青/绿微透明渐变，为玻璃效果提供色彩折射
- **状态卡片**: `.glassEffect(.regular)` 圆角矩形，带 `.symbolEffect(.breathe)` 呼吸动画
- **打卡按钮**: `GlassEffectContainer` 包裹，`.interactive()` 提供触摸缩放/弹跳/微光反馈
- **统计栏**: `.glassEffect(.regular, in: .capsule)` 胶囊形玻璃底栏
- **Toast 提示**: 玻璃材质胶囊，从顶部滑入
- **无障碍**: 尊重 `accessibilityReduceMotion` 系统设置

### 配色

| 元素 | 颜色 |
|------|------|
| 上班按钮/图标 | 蓝色 (.blue) |
| 休息按钮/图标 | 绿色 (.green) |
| 按钮文字 | 白色 (.white) |
| 未打卡状态 | 次要色 (.secondary) |

## 测试

### 单元测试（6 个，全部通过）

**PersistenceServiceTests (4)**:
- `testSaveAndLoad` — JSON 保存和加载
- `testLoadEmpty` — 空文件加载
- `testExportCSV` — CSV 导出格式验证
- `testRoundTrip` — 完整数据往返（含 startTime/endTime/note）

**AttendanceStoreTests (2)**:
- `testMonthlyStats` — 月度统计结构验证
- `testRecordQuery` — 日期查询（未标记日返回 nil）

## 已知限制

| 限制 | 说明 |
|------|------|
| 7 天签名过期 | 免费签名需每周连 Mac 重装，数据不丢失（JSON 在 Documents 目录） |
| Siri 中文识别 | 需真机测试，已提供多种短语变体 |
| 数据备份 | JSON 随 App 删除丢失，后续可加 iCloud 备份 |
| 仅限 iOS 26+ | 使用 Liquid Glass API，不兼容旧版 iOS |

## 构建指南

### 前置条件

- macOS + Xcode 26.2+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- Apple ID（用于免费签名）

### 构建步骤

```bash
# 1. 生成 Xcode 项目
xcodegen generate

# 2. 模拟器编译
xcodebuild -scheme Coldplay -sdk iphonesimulator26.2 SYMROOT=/tmp/ColdplayBuild build

# 3. 真机编译（需在 Xcode 中配置签名团队）
xcodebuild -scheme Coldplay -sdk iphoneos26.2 SYMROOT=/tmp/ColdplayBuild -allowProvisioningUpdates build

# 4. 运行测试
xcodebuild -scheme Coldplay -sdk iphonesimulator26.2 SYMROOT=/tmp/ColdplayBuild \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

> **注意**: 构建输出重定向到 `/tmp/ColdplayBuild` 以避免 iCloud 同步目录的扩展属性问题。

## 版本记录

| 版本 | 日期 | 变更 |
|------|------|------|
| 1.0 | 2026-03-04 | 初始版本：快速打卡、日历同步、统计、Siri、通知、补打卡、Liquid Glass UI |
