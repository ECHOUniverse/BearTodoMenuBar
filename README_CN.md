# Bear Todo Menu Bar

[<img src="https://img.shields.io/badge/Swift-5.9-orange.svg?style=flat-square">](#)
[<img src="https://img.shields.io/badge/macOS-13.0+-blue.svg?style=flat-square">](#)
[<img src="https://img.shields.io/github/license/ECHOUniverse/BearTodoMenuBar.svg?style=flat-square">](https://github.com/ECHOUniverse/BearTodoMenuBar/blob/main/LICENSE)
[<img src="https://img.shields.io/github/v/release/ECHOUniverse/BearTodoMenuBar.svg?style=flat-square">](https://github.com/ECHOUniverse/BearTodoMenuBar/releases)
[<img src="https://github.com/ECHOUniverse/BearTodoMenuBar/actions/workflows/build.yml/badge.svg?style=flat-square">](https://github.com/ECHOUniverse/BearTodoMenuBar/actions/workflows/build.yml)

一个 macOS 菜单栏小工具，自动读取 [Bear](https://bear.app/) 笔记中未勾选的待办事项，并展示在菜单栏中。点击即可在 Bear 中标记完成——使用红色圆圈指示器，风格参考系统提醒事项。

> [English Documentation →](README.md)

## 功能

- 从 Bear 中拉取所有包含未勾选复选框（`- [ ]`）的笔记
- 在菜单栏中按笔记分组展示待办事项
- **一键标记完成** — 点击红色圆圈直接在 Bear 中将 `- [ ]` 变为 `- [x]`
- **视觉指示器** — 未完成显示红色空心圆 ◯，已完成显示实心圆（来自提醒事项同步）
- 通过监视 Bear 数据库变化实现自动刷新（需授权数据库访问）

## 下载与安装

### 方式一：Homebrew（推荐）

```bash
brew tap ECHOUniverse/bear-tap
brew install --cask bear-todo-menu-bar
```

升级：

```bash
brew update && brew upgrade --cask bear-todo-menu-bar
```

### 方式二：从 Release 下载

前往 [Releases](https://github.com/ECHOUniverse/BearTodoMenuBar/releases) 下载最新版本的 `BearTodoMenuBar.zip`，解压后将 `.app` 拖入 `/Applications` 即可。

### 方式三：从源码构建

```bash
# 1. 克隆项目
git clone https://github.com/ECHOUniverse/BearTodoMenuBar.git
cd BearTodoMenuBar

# 2. 构建
swift build

# 3. 打包成 .app
./scripts/build-app.sh

# 4. 本地运行（不安装到 /Applications）
./scripts/run-local.sh

# 5. 或安装到系统
./scripts/run.sh
```

## 首次配置

应用第一次启动后，点击菜单栏图标 →「设置...」，完成以下两步即可全功能运行：

### 1. 配置 API Token

1. 打开 Bear 应用
2. 点击菜单栏 **Help → API Token**
3. 复制生成的 Token
4. 粘贴到本应用的「Bear API Token」输入框中，点击保存

> **注意**：Token 是 Bear 用于 bearcli 通信的凭证，请妥善保管。

### 2. 授权数据库访问

为了让应用能在你编辑 Bear 笔记后自动刷新待办列表，需要授权访问 Bear 的数据库文件夹：

1. 在设置窗口中点击「授权访问 Bear 数据库」
2. 在弹出的文件选择器中，选中 Bear 的 Application Data 文件夹（路径通常为 `~/Library/Group Containers/9K3BFM6K6M.net.shinyfrog.bear/Application Data`）
3. 点击「授权访问」

授权成功后，应用会实时监控数据库变化并自动刷新菜单栏内容。

## 系统要求

| 项目 | 要求 |
|------|------|
| 操作系统 | macOS 13.0+ |
| Swift | 5.9+ |
| 依赖应用 | [Bear](https://bear.app/) |

## 项目结构

```
.
├── Package.swift           # Swift Package Manager 配置
├── Sources/                # 源代码
│   └── BearTodoMenuBar/
│       ├── BearTodoMenuBarApp.swift
│       ├── MenuBarController.swift
│       ├── Views/
│       ├── Services/
│       ├── Models/
│       └── Utils/
├── scripts/
│   ├── build-app.sh        # 构建 .app bundle
│   ├── run-local.sh        # 本地运行（不安装）
│   └── run.sh              # 构建并安装到 /Applications
├── resources/              # 图标等资源
└── README.md
```

## 技术说明

- 使用 Bear 的 [bearcli](https://bear.app/) 获取和编辑笔记数据
- 使用 `DispatchSourceFileSystemObject` 监听 `database.sqlite` 文件变化实现自动刷新
- 使用 Security-Scoped Bookmark 持久化数据库目录访问权限

## 问题反馈

遇到问题？请通过 [GitHub Issues](https://github.com/ECHOUniverse/BearTodoMenuBar/issues) 提交反馈，并尽量提供以下信息：

- macOS 版本
- Bear 版本
- 应用版本号
- 复现步骤

## 贡献

欢迎提交 Pull Request！在提交前请确保：

1. 代码可以通过 `swift build` 编译
2. 遵循现有的代码风格（可通过 `swift-format` 检查）
3. 如有功能变更，请同步更新 README

## License

[MIT](LICENSE)
