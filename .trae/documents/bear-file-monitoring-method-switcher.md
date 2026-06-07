# Bear 文件监控方式 — 文件监控 / bearcli 轮询切换方案

## 摘要

保留现有 `BearFileWatcher`（文件监控）方案，新增 `bearcli` 定时轮询方案。在设置中将"数据库访问授权"卡片改为"Bear 文件监控方式"，使用与语言切换器相同的 GlassEffectContainer 胶囊切换 UI，让用户在两种监控方式之间切换。

***

## 当前状态分析

### 涉及的关键文件

| 文件                          | 当前职责                                                                      |
| --------------------------- | ------------------------------------------------------------------------- |
| `L10n.swift`                | 所有用户可见字符串，含 `databaseAccess` 等键                                           |
| `KeychainStorage.swift`     | 持久化设置：同步开关、同步间隔、开机启动、已完成区域显示                                              |
| `SettingsView.swift`        | 设置面板 UI，语言切换器 (`languageSwitcher`) 使用 GlassEffectContainer + namespace 动画 |
| `MenuBarViewModel.swift`    | 核心 ViewModel：持有 `BearFileWatcher`，管理刷新、debounce、应用切换感知                    |
| `BearFileWatcher.swift`     | 通过 `DispatchSource` 监听 `database.sqlite` 写入事件                             |
| `BearService.swift`         | 通过 `bearcli` 进程执行所有 Bear 数据操作                                             |
| `BearBookmarkManager.swift` | Security-scoped bookmark 管理（Keychain + UserDefaults 双备份）                  |
| `BearTodoMenuBarApp.swift`  | AppDelegate：启动时调用 `startAccessing()`，失败时重试                                |
| `MenuBarContent.swift`      | 菜单栏 UI：`!BearBookmarkManager.shared.hasBookmark` 时显示警告横幅                  |

### 当前数据流

```
文件变更感知:  BearFileWatcher ──(文件监控)──→ database.sqlite ──→ refresh()
               ↑ 需要 BearBookmarkManager 授权

数据读写:      BearService ──(bearcli)──→ Bear.app ──→ database.sqlite
               ↑ 不需要任何权限

应用切换感知:  NSWorkspace 通知 ──→ refresh()
提醒事项变更:  EKEventStoreChanged ──→ refresh()
菜单打开:      menuDidBecomeActive ──→ refresh()
```

### 语言切换器的 UI 模式（参考目标）

`SettingsView.swift:206-262` — `languageSwitcher`:

```swift
// macOS 26+: GlassEffectContainer + Capsule 胶囊 + namespace 动画
GlassEffectContainer(spacing: 0) {
    HStack(spacing: 0) {
        ForEach(Language.allCases, id: \.self) { lang in
            // selected → .glassEffect(.regular.interactive(), in: Capsule())
            // unselected → plain button
        }
    }
}
// macOS < 26: Picker(.segmented)
```

***

## 方案设计

### 1. 新增 `BearMonitorMethod` 枚举

**位置**: `L10n.swift`（与 `Language` 枚举同文件，因为它们共享 UI 模式）

```swift
enum BearMonitorMethod: String, CaseIterable, Codable {
    case fileWatcher  // 文件监控
    case polling      // bearcli 轮询

    var displayName: String {
        switch self {
        case .fileWatcher: return "文件监控"
        case .polling: return "Bear 轮询"
        }
    }
}
```

**决策**: 放在 `L10n.swift` 而非新建文件，因为 `Language` 也在同一个文件中，且此枚举与 UI 标签紧密相关。

***

### 2. `KeychainStorage` — 新增持久化属性

**文件**: `KeychainStorage.swift`

新增 `bearMonitorMethod` 属性，使用 `UserDefaults` 存储（与语言设置一致）：

```swift
private let monitorMethodKey = "bear_monitor_method"

var bearMonitorMethod: BearMonitorMethod {
    get {
        guard let raw = defaults.string(forKey: monitorMethodKey),
              let method = BearMonitorMethod(rawValue: raw) else {
            return .fileWatcher  // 默认：文件监控（保持向后兼容）
        }
        return method
    }
    set {
        defaults.set(newValue.rawValue, forKey: monitorMethodKey)
        NotificationCenter.default.post(name: .bearMonitorMethodDidChange, object: nil)
    }
}
```

发布 `bearMonitorMethodDidChange` 通知，以便 `MenuBarViewModel` 响应切换。

***

### 3. `L10n.swift` — 新增字符串键

**文件**: `L10n.swift`

新增 `StringKey`:

| 键                            | 中文                          | English                                                             |
| ---------------------------- | --------------------------- | ------------------------------------------------------------------- |
| `bearMonitorMethod`          | Bear 文件监控方式                 | Bear Monitor Method                                                 |
| `bearMonitorFileWatcher`     | 文件监控                        | File Watcher                                                        |
| `bearMonitorPolling`         | Bear 轮询                     | Bear Polling                                                        |
| `bearMonitorFileWatcherDesc` | 通过文件系统监控 Bear 数据库变更，实时刷新    | Monitor Bear database changes via file system for real-time refresh |
| `bearMonitorPollingDesc`     | 定时通过 bearcli 检查变更，无需授权数据库访问 | Periodically check via bearcli, no database access required         |

移除旧的数据库访问相关键（如有引用则保留兼容，但 UI 中不再使用）：

* `databaseAccess`、`authorized`、`notAuthorized`、`accessGranted`、`accessNotGranted`、`reauthorize`、`authorizeAccess`、`authorizePrompt`、`authorizeMessage`、`saveAuthFailed`

> **注意**: 这些键在 `MenuBarContent.swift:25` 的 `L10n.noDatabaseAuth` 仍有引用。需要评估是否改为仅文件监控模式显示此警告。

***

### 4. `SettingsView.swift` — 替换数据库授权卡片为监控方式切换卡片

**文件**: `SettingsView.swift`

#### 4.1 新增 State

```swift
@State private var draftMonitorMethod: BearMonitorMethod
```

在 `init()` 中初始化:

```swift
_draftMonitorMethod = State(initialValue: KeychainStorage.shared.bearMonitorMethod)
```

#### 4.2 新增命名空间

```swift
@Namespace private var monitorMethodNamespace
```

#### 4.3 新增监控方式切换器（UI 与语言切换器一致）

```swift
@ViewBuilder
private var monitorMethodSwitcher: some View {
    if #available(macOS 26.0, *) {
        GlassEffectContainer(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(BearMonitorMethod.allCases, id: \.self) { method in
                    let label = Text(method.displayName)
                        .font(.callout)
                        .fontWeight(.medium)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)

                    if draftMonitorMethod == method {
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                draftMonitorMethod = method
                            }
                        } label: { label }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: Capsule())
                        .glassEffectID(method.rawValue, in: monitorMethodNamespace)
                    } else {
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                draftMonitorMethod = method
                            }
                        } label: { label }
                        .buttonStyle(.plain)
                        .glassEffectID(method.rawValue, in: monitorMethodNamespace)
                    }
                }
            }
        }
        .padding(4)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
        )
        .frame(maxWidth: .infinity)
    } else {
        Picker("", selection: $draftMonitorMethod) {
            ForEach(BearMonitorMethod.allCases, id: \.self) { method in
                Text(method.displayName).tag(method)
            }
        }
        .pickerStyle(.segmented)
    }
}
```

#### 4.4 替换 `syncTabContent` 中的数据库授权卡片

**旧代码** (`SettingsView.swift:382-421`): `GlassCard` 含 database access 状态 + 授权按钮

**新代码**: 改为监控方式卡片：

```swift
GlassCard {
    VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 8) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(L10n.bearMonitorMethod)
                .font(.headline)
            Spacer()
            // 文件监控模式下显示授权状态 pill
            if draftMonitorMethod == .fileWatcher {
                StatusPill(
                    icon: isAuthorized ? "checkmark" : "exclamationmark",
                    text: isAuthorized ? L10n.authorized : L10n.notAuthorized,
                    color: isAuthorized ? .green : .orange
                )
                .animation(.default, value: isAuthorized)
            }
        }

        monitorMethodSwitcher

        // 根据模式显示不同的描述
        Text(draftMonitorMethod == .fileWatcher
             ? L10n.bearMonitorFileWatcherDesc
             : L10n.bearMonitorPollingDesc)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

        // 仅在文件监控模式且未授权时显示授权按钮
        if draftMonitorMethod == .fileWatcher && !isAuthorized {
            Button {
                requestBookmark()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "lock.open.fill")
                    Text(L10n.authorizeAccess)
                }
                .font(.callout)
                .fontWeight(.medium)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
    }
}
```

#### 4.5 `saveSettings()` 中保存监控方式

```swift
// Monitor method
if draftMonitorMethod != KeychainStorage.shared.bearMonitorMethod {
    KeychainStorage.shared.bearMonitorMethod = draftMonitorMethod
}
```

***

### 5. `MenuBarViewModel.swift` — 支持两种监控方式

**文件**: `MenuBarViewModel.swift`

#### 5.1 新增轮询 Timer

```swift
private var pollingTimer: Timer?
```

#### 5.2 新增响应切换通知

在 `setupNotifications()` 中新增：

```swift
NotificationCenter.default.addObserver(
    self,
    selector: #selector(monitorMethodDidChange),
    name: .bearMonitorMethodDidChange,
    object: nil
)
```

```swift
@objc private func monitorMethodDidChange() {
    let method = KeychainStorage.shared.bearMonitorMethod
    if method == .fileWatcher {
        stopPolling()
        fileWatcher.startWatching()
    } else {
        fileWatcher.stopWatching()
        startPolling()
    }
}
```

#### 5.3 修改 `init()` / `setupFileWatcher()`

修改 `init()`:

```swift
init() {
    let method = KeychainStorage.shared.bearMonitorMethod
    if method == .fileWatcher {
        setupFileWatcher()
    } else {
        startPolling()
    }
    setupNotifications()
    refresh()
}
```

#### 5.4 新增 `startPolling()` / `stopPolling()`

```swift
private func startPolling() {
    stopPolling()
    let interval = TimeInterval(KeychainStorage.shared.syncInterval)
    // 轮询间隔最小 3 秒，避免 bearcli 过于频繁
    let pollInterval = max(interval > 0 ? interval : 5.0, 3.0)
    pollingTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
        guard let self, !self.bearIsFrontmost else { return }
        self.refresh()
    }
    // tolerance 允许系统合并 timer 以节省电量
    pollingTimer?.tolerance = pollInterval * 0.2
}

private func stopPolling() {
    pollingTimer?.invalidate()
    pollingTimer = nil
}
```

#### 5.5 轮询间隔跟随同步间隔变化

修改 `syncIntervalDidChange()`:

```swift
@objc private func syncIntervalDidChange() {
    let interval = TimeInterval(KeychainStorage.shared.syncInterval)
    remindersDebounce.delay = interval
    fileWatcher.updateSyncInterval(interval)
    // 如果是轮询模式，重启 timer 以应用新间隔
    if KeychainStorage.shared.bearMonitorMethod == .polling {
        startPolling()
    }
}
```

***

### 6. `MenuBarContent.swift` — 更新警告条件

**文件**: `MenuBarContent.swift:19`

**旧代码**:

```swift
if !BearBookmarkManager.shared.hasBookmark {
```

**新代码**:

```swift
if KeychainStorage.shared.bearMonitorMethod == .fileWatcher && !BearBookmarkManager.shared.hasBookmark {
```

仅在文件监控模式且无授权时显示警告。轮询模式不需要此警告。

***

### 7. `BearTodoMenuBarApp.swift` — 条件化启动书签授权

**文件**: `BearTodoMenuBarApp.swift:44-48`

**旧代码**:

```swift
let accessGranted = BearBookmarkManager.shared.startAccessing()
if !accessGranted {
    scheduleBookmarkRetry(attempt: 1)
}
```

**新代码**:

```swift
if KeychainStorage.shared.bearMonitorMethod == .fileWatcher {
    let accessGranted = BearBookmarkManager.shared.startAccessing()
    if !accessGranted {
        scheduleBookmarkRetry(attempt: 1)
    }
}
// 轮询模式：不需要 bookmark，什么都不做
```

***

### 8. 新增通知名称

**文件**: `KeychainStorage.swift`

在文件顶部（与其他 `Notification.Name` extension 一致）：

```swift
extension Notification.Name {
    static let bearMonitorMethodDidChange = Notification.Name("bearMonitorMethodDidChange")
}
```

> 当前 `syncIntervalDidChange` 已在 `KeychainStorage.swift` 中定义，保持一致。

***

## 修改文件总览

| 文件                         | 改动类型 | 改动内容                                        |
| -------------------------- | ---- | ------------------------------------------- |
| `L10n.swift`               | 修改   | 新增 `BearMonitorMethod` 枚举；新增 6 个字符串键        |
| `KeychainStorage.swift`    | 修改   | 新增 `bearMonitorMethod` 属性 + 通知定义            |
| `SettingsView.swift`       | 修改   | 新增 `monitorMethodSwitcher`；替换数据库授权卡片；保存监控方式 |
| `MenuBarViewModel.swift`   | 修改   | 新增轮询 Timer；响应监控方式切换；条件化 `setupFileWatcher`  |
| `MenuBarContent.swift`     | 修改   | 警告横幅仅在文件监控模式且无授权时显示                         |
| `BearTodoMenuBarApp.swift` | 修改   | 仅在文件监控模式时调用 `startAccessing()`              |

**无需新建文件**。

***

## 假设与决策

1. **默认值**: `bearMonitorMethod` 默认为 `.fileWatcher`，保证现有用户升级后行为不变
2. **轮询间隔**: 使用同步间隔设置（`KeychainStorage.shared.syncInterval`），最小 3 秒，默认 5 秒
3. **bearcli 不存在时**: 轮询模式下的 refresh() 通过 `BearService.fetchAllUncheckedTodos` 已有错误处理，失败时静默跳过
4. **Tolerance**: 轮询 Timer 设置 20% tolerance，允许系统合并 timer 以节省电量
5. **bearcli 轮询时 Bear 在前台**: 跳过刷新（与文件监控行为一致，避免干扰用户编辑）
6. **旧数据库授权字符串**: 保留在 `StringKey` 枚举中（兼容可能的其他引用），但 UI 中不再使用

***

## 验证步骤

1. **构建成功**: `swift build`
2. **功能验证**:

   * 默认模式（文件监控）：行为与现有版本一致

   * 切换到 Bear 轮询：数据库授权状态 pill 消失，菜单栏不显示警告横幅

   * 文件监控未授权时：显示授权按钮，点击可打开 NSOpenPanel

   * 切换回文件监控：恢复授权状态显示

   * 轮询模式下：应用切换时仍能正确刷新

   * 轮询间隔跟随同步间隔设置变化
3. **设置保存**: 退出应用后重新启动，监控方式选择持久化

