# 设置界面 - 关于与更新 Tab 页

## 摘要

在设置窗口中新增 "关于与更新" tab 页，展示 App 信息、版本号、检查更新功能，风格符合 macOS 26 Liquid Glass 设计规范。

## 当前状态分析

### 现有架构

* **SettingsView** (`SettingsView.swift`): 使用 `SettingsTab` 枚举管理两个 Tab（`general` / `sync`），通过 `#available(macOS 26.0, *)` 分支使用 `GlassEffectContainer` 的 Liquid Glass 分段控件，低版本回退 `Picker(.segmented)`。

* **DesignComponents** (`DesignComponents.swift`): 提供 `GlassCard`、`StatusPill`、`LiquidGlassCircleButton` 等 Liquid Glass 风格组件。

* **L10n** (`L10n.swift`): 通过 `StringKey` 枚举 + `zhStrings`/`enStrings` 字典实现双语。

* **Info.plist**: `CFBundleShortVersionString` = `2.3.0`，`CFBundleVersion` = `2.3.0`。

* **AppDelegate** (`BearTodoMenuBarApp.swift`): 创建 settings `NSWindow`，最小尺寸 420×420。

* **版本管理**: `build-app.sh` 通过 `$VERSION` 环境变量注入 plist。

### App 分发方式

* 自发布（GitHub Releases），非 App Store / Sparkle。

* 已有 GitHub 仓库链接 `github.com/ECHOUniverse/BearTodoMenuBar`。

## 修改计划

### 1. `L10n.swift` — 新增 i18n 字符串

新增 `StringKey` 枚举值和对应的中英文翻译：

| 新增 Key                | 中文      | English                  |
| --------------------- | ------- | ------------------------ |
| `about`               | 关于与更新   | About & Updates          |
| `appVersion`          | 版本      | Version                  |
| `checkForUpdates`     | 检查更新    | Check for Updates        |
| `checking`            | 正在检查... | Checking...              |
| `upToDate`            | 已是最新版本  | Up to Date               |
| `newVersionAvailable` | 有新版本 %@ | New Version %@ Available |
| `updateFailed`        | 检查更新失败  | Update Check Failed      |
| `openDownloadPage`    | 打开下载页面  | Open Download Page       |

在 `zhStrings` 和 `enStrings` 字典中添加对应翻译，并添加对应的 `static var` 计算属性。

### 2. `SettingsView.swift` — 新增关于 Tab

#### 2.1 `SettingsTab` 枚举添加 `.about` case

```swift
case about

var title: String {
    case .about: return L10n.about
}
var icon: String {
    case .about: return "info.circle.fill"
}
```

#### 2.2 新增 `aboutTabContent` ViewBuilder

在设置页面内容区域添加关于 Tab 的渲染分支（与 `generalTabContent` / `syncTabContent` 同级）。内容包含：

**App 信息卡片 (`GlassCard`)：**

* App 图标（从 `NSApp.applicationIconImage` 或 Bundle icon 获取，渲染为 64×64 圆角矩形）

* App 名称 `BearTodoMenuBar`（从 `Bundle.main` 获取）

* 版本号 `2.3.0`（从 `CFBundleShortVersionString` 读取）

* 版权/开发者信息

**更新卡片 (`GlassCard`)：**

* "检查更新" 按钮（Liquid Glass 风格）

* 状态文本（检查中 / 已是最新 / 有新版本）

* 若有新版本，显示 "打开下载页面" 链接按钮

**Liquid Glass 设计要点：**

* 使用 `.ultraThinMaterial` + `RoundedRectangle(cornerRadius: 16)` — 与现有 `GlassCard` 一致

* macOS 26 风格图标大而突出，使用 `.glassEffect` 修饰

* 按钮使用 `SpringPressButtonStyle`

* 进入动画使用 `staggeredEntrance`

#### 2.3 关于 Tab 不需要 Save/Cancel

关于 Tab 是只读展示页，不需要保存草稿状态。但当前 Save/Cancel 按钮是所有 tab 共享的底部栏。实现方式：

* 当 `selectedTab == .about` 时，底部栏隐藏 Save 按钮，仅显示 Cancel（关闭）按钮。

* 或更简单：Save 按钮在 about tab 时 disabled/隐藏。

### 3. 检查更新逻辑

#### 实现方式

使用 `URLSession` 异步请求 GitHub API 获取最新 release：

```
GET https://api.github.com/repos/ECHOUniverse/BearTodoMenuBar/releases/latest
```

解析 `tag_name` 字段（去掉前缀 `v` 如 `v2.4.0` → `2.4.0`），与当前 `CFBundleShortVersionString` 比较。

#### 版本比较

使用简单的三段式语义版本比较（`major.minor.patch`），不引入额外依赖。

#### 状态机

```
idle → checking → upToDate / updateAvailable(version) / error(message)
```

在 `SettingsView` 中添加 `@State`：

* `updateCheckState: UpdateCheckState = .idle`

* `latestVersion: String?`

### 4. 文件变更清单

| 文件                                                 | 变更类型 | 说明                                         |
| -------------------------------------------------- | ---- | ------------------------------------------ |
| `Sources/BearTodoMenuBar/Services/L10n.swift`      | 修改   | 新增 8 个 i18n key                            |
| `Sources/BearTodoMenuBar/Views/SettingsView.swift` | 修改   | 新增 `.about` tab + aboutTabContent + 更新检查逻辑 |

## 假设与决策

1. **更新检查通过 GitHub API**：App 是自发布，无 Sparkle/App Store。使用公开 GitHub API 查询最新 release（无需认证，频率限制 60 req/h）。
2. **不缓存更新状态**：每次打开 About tab 时重新检查，不持久化。
3. **版本比较为三段式**：`major.minor.patch` 数值比较，忽略 pre-release 后缀。
4. **About tab 不依赖 draft 状态**：无需 Save/Cancel，只读展示。
5. **macOS 26 Liquid Glass**：使用已有的 `GlassCard`、`GlassEffectContainer`、`SpringPressButtonStyle` 组件，保持视觉一致性。

## 验证步骤

1. `swift build` 编译通过
2. 运行 App → 打开设置 → 确认三个 Tab 正常切换
3. 关于 Tab 显示正确的 App 图标、名称和版本号
4. 点击 "检查更新" → 正确请求 GitHub API → 显示结果
5. 切换语言（中/英）→ 关于 Tab 文本正确切换
6. macOS 26 环境确认 Liquid Glass 风格正确渲染
7. 低版本 macOS（< 26）确认回退样式正常

