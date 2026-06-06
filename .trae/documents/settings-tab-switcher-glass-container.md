# 设置界面标签切换器 — Liquid Glass 容器

## 摘要

为设置界面的 tab switcher 添加一个 capsule 形状的 Liquid Glass 风格外层容器，使其在视觉上与 macOS 26 设计语言保持一致。

## 当前状态分析

### 涉及文件

| 文件                                                           | 说明                                                                             |
| ------------------------------------------------------------ | ------------------------------------------------------------------------------ |
| `Sources/BearTodoMenuBar/Views/SettingsView.swift` (144-187) | tab switcher 实现，两条路径：macOS 26 `GlassEffectContainer` / 回退 `Picker(.segmented)` |
| `Sources/BearTodoMenuBar/Views/DesignComponents.swift`       | 现有 Liquid Glass 组件（GlassCard、LiquidGlassCircleButton 等）                        |

### 现有 macOS 26 tab switcher 结构 (146-171)

```
GlassEffectContainer(spacing: 0)
  └── HStack(spacing: 0)
        └── ForEach tabs → Button
              ├── icon + text
              ├── .glassEffect(... in: Capsule())      ← 每个 tab 独立 capsule
              └── .glassEffectID(...)
```

**问题**：每个 tab 按钮是独立的 capsule，整体没有可见的容器边界。缺少一个包裹所有 tab 的 Liquid Glass 胶囊容器。

### 现有设计模式（DesignComponents.swift）

所有组件共享一致的 Liquid Glass 视觉语言：

* `.ultraThinMaterial` 填充

* `.continuous` 圆角

* `Color.primary.opacity(0.08)` 描边

* Spring 动画

## 方案

### 变更：仅修改 macOS 26.0+ 路径

在 `GlassEffectContainer` 外层包裹一个 capsule 形状的 Liquid Glass 容器。

**新结构**：

```
// 外层：Capsule Liquid Glass 容器
Capsule().fill(.ultraThinMaterial) + stroke
  └── GlassEffectContainer(spacing: 0)
        └── HStack(spacing: 0)
              └── ForEach tabs → Button (保持不变)
```

### 具体修改（SettingsView\.swift 146-171）

```swift
if #available(macOS 26.0, *) {
    GlassEffectContainer(spacing: 0) {
        HStack(spacing: 0) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                // ... 现有 button 代码不变 ...
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
}
```

关键变化：

1. 在 `GlassEffectContainer` 上添加 `.padding(4)` — 让内部内容与容器边缘有间距
2. 添加 `.background(Capsule(...).fill(.ultraThinMaterial).stroke(...))` — 外层 Liquid Glass 胶囊
3. `.glassEffect` / `.glassEffectID` per-tab 保持不变 — 选中态的高亮交互
4. 视觉样式与 `DesignComponents.swift` 中 `GlassCard` / `GlassEffectCircleButton` 一致

### 不变部分

* macOS < 26.0 回退路径：`Picker(.segmented)` 已有原生胶囊容器，无需修改

* Tab 内容切换动画：不变

* `SettingsTab` 枚举：不变

* `@Namespace private var tabNamespace`：不变

## 假设与决策

1. **不需要新的 DesignComponents 组件** — 直接内联 capsule glass 背景，复用现有设计模式常量（`.ultraThinMaterial`, `opacity(0.08)`）
2. **`GlassEffectContainer`** **保持** **`spacing: 0`** — tab 之间紧贴，边界由外层 capsule 定义
3. **回退路径不改** — `Picker(.segmented)` 在上线 macOS 之前的版本上已有原生外观

## 验证

1. **构建**：`swift build` 编译通过
2. **运行**：`./scripts/run.sh -l` 在 macOS 26 上验证设置窗口 tab switcher 显示为 capsule Liquid Glass 容器
3. **视觉效果检查**：确认外层 capsule 容器 + 内部 tab 选中 highlight 的 Liquid Glass 效果正常

