# Bear Todo Menu Bar

一个 macOS 菜单栏小工具，自动读取 [Bear](https://bear.app/) 笔记中未勾选的待办事项，并展示在菜单栏中。支持点击待办直接跳转回 Bear 对应笔记。

## 功能

- 从 Bear 中拉取所有包含未勾选复选框（`- [ ]`）的笔记
- 在菜单栏中按笔记分组展示待办事项
- 点击待办即可在 Bear 中打开对应笔记
- 通过监视 Bear 数据库变化实现自动刷新（需授权数据库访问）
- 通过 x-callback-url 与 Bear 通信，数据不落第三方服务器

## 系统要求

- macOS 13.0+
- Swift 5.9+
- 已安装 [Bear](https://bear.app/) 应用

## 快速开始

### 1. 克隆项目

```bash
git clone <repo-url>
cd Bear-checkbox-to-reminder
```

### 2. 构建

```bash
swift build
```

或打包成 `.app`：

```bash
./scripts/build-app.sh
```

### 3. 运行（本地试用）

不安装到 `/Applications`，直接从构建目录启动：

```bash
./scripts/run-local.sh
```

### 4. 安装到系统（长期使用）

```bash
./scripts/run.sh
```

这会构建、复制到 `/Applications`、注册 URL Scheme 并启动应用。

## 首次配置

应用第一次启动后，点击菜单栏图标 →「设置...」，完成以下两步即可全功能运行：

### 1. 配置 API Token

1. 打开 Bear 应用
2. 点击菜单栏 **Help → API Token**
3. 复制生成的 Token
4. 粘贴到本应用的「Bear API Token」输入框中，点击保存

> **注意**：Token 是 Bear 用于 x-callback-url 通信的凭证，请妥善保管。

### 2. 授权数据库访问

为了让应用能在你编辑 Bear 笔记后自动刷新待办列表，需要授权访问 Bear 的数据库文件夹：

1. 在设置窗口中点击「授权访问 Bear 数据库」
2. 在弹出的文件选择器中，选中 Bear 的 Application Data 文件夹（路径通常为 `~/Library/Group Containers/9K3BFM6K6M.net.shinyfrog.bear/Application Data`）
3. 点击「授权访问」

授权成功后，应用会实时监控数据库变化并自动刷新菜单栏内容。

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
└── README.md
```

## 技术说明

- 使用 Bear 的 [x-callback-url](https://bear.app/xcallbackurl/) 获取笔记数据
- 使用 `DispatchSourceFileSystemObject` 监听 `database.sqlite` 文件变化实现自动刷新
- 使用 Security-Scoped Bookmark 持久化数据库目录访问权限

## License

MIT
