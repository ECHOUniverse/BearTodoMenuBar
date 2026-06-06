# 设置界面 UI 问题修复

## 摘要

三个问题修复：
1. 缩小设置窗口初始默认宽高
2. 修复语言选择器容器不自适应宽度
3. 修复标签页切换器容器和过渡动画

---

## 当前状态分析

### 问题 1：窗口太宽

[BearTodoMenuBarApp.swift#L57-L63](file:///Volumes/WD-1T/00_Workspace/00_Active/CodeProject/Bear_Todo_Menubar/Sources/BearTodoMenuBar/BearTodoMenuBarApp.swift#L57-L63)

当前值：
- `minWidth: 560` — 最小宽度过大
- `idealWidth: 640` — 理想宽度过大
- `width: 640` — 初始宽度过大
- `height: 500` — 偏高

单栏标签页布局下内容更紧凑，不需要这么宽。

### 问题 2：语言选择器卡片宽度不适配

[SettingsView.swift#L189-L209](file:///Volumes/WD-1T/00_Workspace/00_Active/CodeProject/Bear_Todo_Menubar/Sources/BearTodoMenuBar/Views/SettingsView.swift#L189-L209)

语言卡片对比开机启动卡片：
```swift
// 语言卡片 — 缺少 Spacer()，HStack 不撑满宽度
HStack(spacing: 8) {
    Image(systemName: "globe")
    Text(L10n.language)
    // ← 缺少 Spacer()
}

// 开机启动卡片 — 有 Spacer()，HStack 撑满宽度
HStack(spacing: 8) {
    Image(systemName: "power")
    Text(L10n.launchAtLogin)
    Spacer() // ← 有 Spacer()
}
```

语言卡片的 `HStack` 缺少 `Spacer()`，导致卡片宽度无法随窗口缩放自适应。同时 `Picker(.segmented)` 的中文文本天然更宽，需要显式约束。

### 问题 3：标签页切换器过渡动画不生效

[SettingsView.swift#L81-L100](file:///Volumes/WD-1T/00_Workspace/00_Active/CodeProject/Bear_Todo_Menubar/Sources/BearTodoMenuBar/Views/SettingsView.swift#L81-L100)

当前标签页切换使用 `switch selectedTab` 展示内容，配合 `.transition(.asymmetric(...))` + `.animation(...)`。但 **`switch` 语句中，上一个分支视图被移除时，`.transition` 无法生效**，因为 SwiftUI 的 transition 需要两个视图同时在视图树中才能计算进出动画。

正确做法：使用 `ZStack` + `if` 条件判断，让两个标签页视图始终存在于视图树中，transition 才能正确触发。

另外，`GlassEffectContainer` + `glassEffectID` 的 morphing 动画已经正确配置在 macOS 26+ 路径，保持不变。

---

## 修改计划

### 文件变更清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `Sources/BearTodoMenuBar/BearTodoMenuBarApp.swift` | 编辑 | 缩小窗口尺寸 |
| `Sources/BearTodoMenuBar/Views/SettingsView.swift` | 编辑 | 修复语言卡片宽度 + 修复内容切换动画 |

### 1. BearTodoMenuBarApp.swift — 缩小窗口尺寸

```swift
// 修改前
.frame(minWidth: 560, idealWidth: 640, minHeight: 480)
// → 修改后
.frame(minWidth: 420, idealWidth: 460, minHeight: 380)

// 修改前
contentRect: NSRect(x: 0, y: 0, width: 640, height: 500),
// → 修改后
contentRect: NSRect(x: 0, y: 0, width: 460, height: 420),
```

### 2. SettingsView.swift — 修复语言卡片宽度

在 `generalTabContent` 的语言 `GlassCard` 内，为 header `HStack` 添加 `Spacer()`：

```swift
// 修改前
HStack(spacing: 8) {
    Image(systemName: "globe")
        .font(.title3)
        .foregroundStyle(.secondary)
    Text(L10n.language)
        .font(.headline)
}
// 修改后
HStack(spacing: 8) {
    Image(systemName: "globe")
        .font(.title3)
        .foregroundStyle(.secondary)
    Text(L10n.language)
        .font(.headline)
    Spacer()
}
```

### 3. SettingsView.swift — 修复标签页切换过渡动画

将内容区域从 `switch` 改为 `ZStack` + `if`，确保 transition 动画生效：

```swift
// 修改前
VStack(alignment: .leading, spacing: 8) {
    switch selectedTab {
    case .general:
        generalTabContent
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .leading)),
                removal: .opacity.combined(with: .move(edge: .trailing))
            ))
    case .sync:
        syncTabContent
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .trailing)),
                removal: .opacity.combined(with: .move(edge: .leading))
            ))
    }
}
.frame(maxWidth: .infinity)
.animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedTab)

// 修改后
ZStack {
    if selectedTab == .general {
        generalTabContent
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .leading)),
                removal: .opacity.combined(with: .move(edge: .trailing))
            ))
    }
    if selectedTab == .sync {
        syncTabContent
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .trailing)),
                removal: .opacity.combined(with: .move(edge: .leading))
            ))
    }
}
.frame(maxWidth: .infinity)
.animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedTab)
```

**关键差异**：`ZStack` 中两个 `if` 分支的视图始终共存于视图树，当 `selectedTab` 变化时，一个视图插入、另一个视图移除，`transition` 正确触发动画。`switch` 中只有一个分支存在，transition 无机会生效。

---

## 假设与决策

1. **窗口缩小范围**：单栏布局内容少，420×380 的最小尺寸 + 460×420 的默认尺寸足够容纳所有内容。
2. **语言卡片修复只需添加 Spacer()**：与项目中其他 GlassCard 保持一致的模式（header 带 Spacer()），不需要额外容器调整。
3. **tabSwitcher 容器和动画已正确**：macOS 26+ 路径的 `GlassEffectContainer` + `glassEffectID` + morphing 动画正确；`< macOS 26` 路径 `Picker(.segmented)` 自带系统动画。保持现有实现不变。

---

## 验证步骤

1. `swift build` — 编译通过
2. 运行应用 → 打开设置窗口 → 窗口默认尺寸约 460×420
3. 调整窗口宽度 → 语言卡片与其他卡片同步缩放，宽度一致
4. 点击标签页切换 → 内容有滑入/滑出过渡动画（而非无动画切换）
5. 所有功能正常（语言切换、开关、保存/取消）
