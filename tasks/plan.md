# BearTodoMenuBar 2.7 — macOS 27 从零重构计划

## 目标

完全重写应用，保留三项核心功能，严格遵循 macOS 27 / Swift 6 / Liquid Glass 最新标准：
1. **Bear 待办管理** — 通过 bearcli 搜索/编辑/打开 Bear 笔记中的 checkbox
2. **系统提醒事项同步** — 双向同步 Bear todo ↔ Reminders.app
3. **菜单栏查看** — MenuBarExtra 中展示待办、完成、过期事项

## 架构设计

```
Sources/BearTodoMenuBar/
├── App/
│   ├── BearTodoMenuBarApp.swift    // @main App, MenuBarExtra + Settings Scene
│   └── AppDelegate.swift           // NSApplicationDelegate, 设置窗口管理
├── Models/
│   ├── TodoItem.swift              // Sendable 数据模型
│   └── Settings.swift              // 设置模型（@Observable）
├── Services/
│   ├── BearService.swift           // async/await bearcli 封装
│   ├── ReminderService.swift       // async/await EventKit 同步
│   ├── TodoParser.swift            // Markdown checkbox 解析
│   └── MonitorService.swift        // 文件监控 + 轮询 统一服务
├── Persistence/
│   └── KeychainStorage.swift       // @Observable 持久化设置
├── ViewModel/
│   └── MenuBarViewModel.swift      // @Observable @MainActor 主视图模型
├── Views/
│   ├── MenuBar/
│   │   ├── MenuBarContent.swift    // 菜单栏主布局
│   │   ├── BearTodoRow.swift       // Bear 待办行
│   │   └── ReminderRow.swift       // 提醒事项行
│   ├── Settings/
│   │   ├── SettingsView.swift      // 设置面板
│   │   ├── GeneralTab.swift        // 一般设置
│   │   ├── SyncTab.swift           // 同步设置
│   │   └── AboutTab.swift          // 关于
│   └── Design/
│       ├── GlassCard.swift         // Liquid Glass 卡片
│       ├── StatusPill.swift        // 状态指示器
│       └── StaggeredEntrance.swift // 交错入场动画
└── Resources/
    ├── Info.plist
    └── AppIcon.icns
```

## 核心技术决策

### 1. 数据流: `@Observable` 替代 `@ObservableObject`
- 使用 `@Observable` 宏（Swift 27），按属性粒度追踪变更
- 无需 `@Published`、`objectWillChange` 样板代码
- 视图只传递它们实际读取的字段

### 2. 并发: Swift 6 async/await
- BearService: `async throws` API，`Process` 用 `withCheckedThrowingContinuation` 包装
- ReminderService: `@MainActor` actor 隔离，EventKit 用 `@preconcurrency import EventKit`
- ViewModel: `@Observable @MainActor`，所有 UI 更新在主 actor

### 3. @State 初始化: SDK 27 宏语法
- 声明无初始值: `@State private var selectedTab: SettingsTab`
- init 中直接赋值: `self.selectedTab = .general`（不用 `_tab = State(initialValue:)`）

### 4. View 架构: 每个 Section 独立 View struct
- 遵循 `swiftui-specialist/structure.md` 规范
- 每个 View struct 自带 invalidation boundary
- 不使用 `private var computedProperty: some View` 或 `@ViewBuilder` helpers

### 5. Liquid Glass 设计
- `GlassEffectContainer` + `.glassEffect()` 用于胶囊选择器
- `.ultraThinMaterial` + `RoundedRectangle` stroke 用于卡片
- `Capsule` 形状用于标签切换器
- 无 `#available` 守卫（目标 macOS 26+）

### 6. Package 配置
- `swift-tools-version: 6.2`
- `platforms: [.macOS(.v26)]`
- `swiftSettings: [.swiftLanguageMode(.v6)]`（从零写不惧 Swift 6）

## 分阶段实施

### 阶段 0: 搭建骨架（数据模型 + 包配置）
- Package.swift 配置
- 所有 Sendable 数据模型
- Info.plist

### 阶段 1: 核心服务层
- TodoParser（纯函数，无依赖）
- BearService（async/await + Process）
- ReminderService（async/await + EventKit）
- MonitorService（文件监控 + 轮询）

### 阶段 2: 持久化 & ViewModel
- KeychainStorage（@Observable 设置）
- MenuBarViewModel（@Observable @MainActor）

### 阶段 3: 菜单栏 UI
- DesignComponents（Liquid Glass 组件）
- MenuBarContent + BearTodoRow + ReminderRow
- App 入口 + MenuBarExtra

### 阶段 4: 设置 UI
- SettingsView + 三个 Tab
- AppDelegate 设置窗口管理

### 阶段 5: 集成验证
- 完整编译
- 运行验证
- 本地化（L10n）

## 关键风险

| 风险 | 缓解 |
|---|---|
| EventKit 非 Sendable | `@preconcurrency import EventKit` + 专用 actor |
| bearcli 进程管理 | `withCheckedThrowingContinuation` 包装 Process |
| @Observable 与 MenuBarExtra | 验证 macOS 27 MenuBarExtra 支持 @Observable |
| 文件监控安全作用域 | GCD DispatchSource + Bookmark 管理（保留原实现） |
