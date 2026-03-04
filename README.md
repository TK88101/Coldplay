# Coldplay — 考勤助手

极简 iOS 考勤打卡应用，专为不固定休息日的工作模式设计。

每天点一个按钮标记"上班"或"休息"，自动同步到 iPhone 日历。

<p align="center">
  <strong>iOS 26 | Swift 5.9 | SwiftUI | Liquid Glass</strong>
</p>

## 功能

- **一键打卡** — 两个大按钮，上班(蓝) / 休息(绿)，同一天重复点击只保留最后一次
- **补打卡** — 忘记打卡？选择历史日期补录
- **日历同步** — 自动创建"考勤"专用日历，上班写入 12:00-20:00 时间段事件，休息写入全天事件
- **累计统计** — 底部显示总上班天数、休息天数、工时（每工作日 8 小时）
- **每日提醒** — 12:00 推送通知"今天上班吗？"
- **Siri 语音** — "用 Coldplay 记录上班" / "用 Coldplay 记录休息"
- **CSV 导出** — 导出考勤记录通过系统分享发送
- **Confetti 特效** — 打卡成功后纸花庆祝动画

## 截图

iOS 26 Liquid Glass 风格界面，玻璃材质按钮带触摸反馈。

## 技术栈

| 项目 | 选型 |
|------|------|
| 语言 | Swift 5.9 |
| 框架 | SwiftUI + iOS 26 Liquid Glass |
| 日历 | EventKit |
| 语音 | App Intents |
| 通知 | UserNotifications |
| 存储 | 本地 JSON |
| 动画 | [ConfettiSwiftUI](https://github.com/simibac/ConfettiSwiftUI) |
| 项目管理 | [XcodeGen](https://github.com/yonaskolb/XcodeGen) |

## 快速开始

### 前置条件

- macOS + Xcode 26.2+
- XcodeGen: `brew install xcodegen`
- Apple ID（用于免费签名）

### 构建

```bash
# 生成 Xcode 项目
xcodegen generate

# 模拟器构建
xcodebuild -scheme Coldplay -sdk iphonesimulator26.2 SYMROOT=/tmp/ColdplayBuild build

# 真机构建（推荐在 Xcode GUI 中操作）
xcodebuild -scheme Coldplay -sdk iphoneos26.2 SYMROOT=/tmp/ColdplayBuild -allowProvisioningUpdates build
```

### 测试

```bash
xcodebuild -scheme Coldplay -sdk iphonesimulator26.2 SYMROOT=/tmp/ColdplayBuild \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

6 个单元测试覆盖持久化服务和核心业务逻辑。

## 项目结构

```
Coldplay/
├── App/ColdplayApp.swift              # 入口，注册通知
├── Models/AttendanceRecord.swift       # 数据模型
├── Services/
│   ├── CalendarService.swift           # EventKit 日历创建/事件管理
│   ├── PersistenceService.swift        # JSON 读写 + CSV 导出
│   └── NotificationService.swift       # 每日 12:00 提醒
├── Store/AttendanceStore.swift         # @Observable 单例，核心逻辑
├── Views/ContentView.swift             # 主界面 (Liquid Glass)
└── Intents/                            # Siri 快捷指令
    ├── MarkWorkIntent.swift
    ├── MarkRestIntent.swift
    └── AttendanceShortcuts.swift
```

## 已知限制

- **iOS 26+** — 使用 Liquid Glass API，不兼容旧版 iOS
- **免费签名** — 7 天过期需重装，数据不丢失
- **Siri 中文** — 需真机测试，已提供多种短语变体
- **数据备份** — 随 App 删除丢失，后续可加 iCloud 备份

## 许可

个人项目，仅供学习参考。
