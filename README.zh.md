# Open YouTube Music (OpenYTMusic)

专为 macOS 打造的高性能、优雅的 YouTube Music 原生桌面客户端，完全使用 **Pure Swift 与 SwiftUI** 原生编写，并配备零 Xcode 命令行编译管道。

旨在提供极致轻量的内存占用、出色的系统融合度以及 macOS 独有的原生桌面美学。

---

## 🎨 核心特性

- **macOS 原生毛玻璃美学**：使用系统级 `NSVisualEffectView` 实现窗口背景的毛玻璃磨砂半透明效果，完美契合 macOS 系统原生外观，并支持系统深色/浅色模式的自动无缝切换。
- **纯原生底部播放控制栏**：完全隐藏网页版默认的播放控制栏，替换为符合 macOS 设计规范、界面极致精美的自定义 SwiftUI 原生控制栏。
- **锁屏与系统控制中心同步**：通过 `MPNowPlayingInfoCenter` 与 macOS 系统控制中心及锁屏界面完美同步当前播放曲目的元数据（歌名、歌手、专辑名、封面图），并全面支持物理键盘媒体键（播放/暂停、上一首、下一首）的原生交互控制。
- **状态栏菜单小组件**：超轻量的 macOS 顶部菜单栏常驻小图标（`NSStatusItem`），动态显示当前播放歌名，并延伸出原生下拉控制菜单。
- **双面板实时滚动同步歌词**：具备 Apple Music 风格的侧边栏滚动歌词面板，以及 QQ Music 风格的透明悬浮桌面歌词秀。针对歌词匹配进行了深度优化，具备繁简翻译容错重试及歌名双向校验机制，达成极高匹配成功率。
- **极速流畅的进度条拖拽**：时间轴进度条支持直接拖拽定位，在拖拽期间自动挂起播放器时间回传以防进度条抖动挣扎，提供丝滑的拖拽寻道体验。

---

## 🛠 编译与启动

本项目采用了零依赖、零 Xcode 命令行构建管道。要在您的 macOS 设备上进行本地编译与运行：

1. 在终端中进入本项目的根目录。
2. 运行编译构建脚本：
   ```bash
   ./build.sh
   ```
脚本将自动清理历史缓存、编译所有 Swift 源文件、组装原生的 macOS 应用包结构（`build/Open YouTube Music.app`）、将原版 PNG 图标转换为多分辨率的系统级 `.icns` 图标包，并直接启动应用。

---

## 🔓 macOS Gatekeeper 签名警告打不开的解决方法

由于在 GitHub Releases 中分发的预编译 `.app` 安装包没有使用昂贵的 Apple 开发者账号进行证书签名，macOS Gatekeeper 安全机制可能会拦截该应用的首次打开，并弹出诸如 *“Open YouTube Music 已损坏，无法打开”* 或 *“无法验证开发者”* 的警告。

您可以通过以下两种非常标准的 macOS 官方方法轻松绕过并解决此问题：

### 方法一：Finder 右键绕过（最推荐，简单快捷）
1. 在 Finder 中找到解压出来的 **Open YouTube Music** 应用（通常在 `下载` 或 `应用程序` 文件夹内）。
2. **右键（或按住 Control 键点击）**应用图标，在弹出的右键菜单中选择 **“打开” (Open)**。
3. 系统仍会弹出类似的 Gatekeeper 确认警告框，但此时警告框内会多出一个明确的 **“打开” (Open)** 按钮。点击它！
4. 此操作仅需在首次启动时进行一次。从此以后，您只需正常双击即可直接流畅打开应用！

### 方法二：在终端中移除 Quarantine 隔离属性（极客推荐）
打开终端（Terminal.app），输入并运行以下命令，即可彻底剥离该应用包的 macOS 隔离标识：
```bash
xattr -cr "/Applications/Open YouTube Music.app"
```
*(如果应用目前在您的下载文件夹，请将路径相应调整为 `~/Downloads/Open\ YouTube\ Music.app`。)*

---

## ⚖ 商标与法律免责声明

**Open YouTube Music**（亦被称为 **OpenYTMusic** 或 **OpenYTM**）是一个**开源的、由社区驱动的免费桌面工具**。

- 本应用 **不隶属于、未授权、未维护、未赞助或未背书** 于 Google LLC、YouTube 或其任何关联公司或注册商标持有者。
- YouTube 和 YouTube Music 是 Google LLC 的注册商标。
- 本项目及其文档中使用的所有商标词汇、服务名称或品牌 Logo 仅用于 **指代性、描述性及兼容性目的**，旨在依合理使用原则告知用户此开源客户端所访问的第三方网页服务。
- 客户端 WebKit 窗口中加载的所有媒体资产、音频流、歌词及网页内容均直接流式传输自官方服务器，其知识产权与所有权完全归属其各自的官方创作者与商标持有者。

---

## 📂 项目结构

- `build.sh` — 编译、打包与启动自动化脚本。
- `icon.png` — 放置在项目根目录下的原汁原味 3D 拟物化官方 App 图标，供 `baomi.app` 官网抓取展示。
- `src/assets/icon.png` — 应用打包编译使用的官方 App 图标模板。
- `src/swift/main.swift` — 应用程序入口、App Delegate 生命周期及窗口管理器。
- `src/swift/ThemeCSS.swift` — 注入到 WebKit 中的 CSS 视觉样式表。
- `src/swift/WebView.swift` — WebKit 浏览器配置、JS 消息桥接器与广告过滤核心。
- `src/swift/LyricsViews.swift` — 底部原生控制栏及双面板歌词的 SwiftUI 视图层。
- `src/swift/LyricsManager.swift` — LRC 歌词解析与元数据检索瀑布流控制器。
- `src/swift/NowPlayingManager.swift` — 系统媒体控制中心与物理键盘按键桥接器。
- `src/swift/TrayManager.swift` — macOS 顶部状态栏 Widget 菜单。
