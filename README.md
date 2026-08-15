# rShot

轻便的 macOS 原生截图工具：截图、标注、OCR 三合一。常驻菜单栏，快捷键触发，框选即标注，完成即复制——克制、专业、轻量。

对标 iShot Pro / CleanShot X，用 **Swift + SwiftUI** 原生构建，无 Electron、无内嵌浏览器，Release 产物仅 ~3.5 MB。

## 功能

### 截图
- **区域截图**（⇧⌘A）：拖拽框选，选区所见即所得
- **窗口截图**：框选模式下滑过任意窗口自动高亮，单击截取整窗
- **全屏截图**（⇧⌘S）
- 三种模式互斥，会话中不会误触发
- ESC 随时取消

### 标注（iShot 式原位编辑）
框选松手后**不弹新窗口**——截图留在屏幕原位、四周暗色遮罩，工具栏浮岛出现在选区下方（空间不足时自动上移/居中）：

- **矩形框选**、**箭头**（实心三角头）、**高亮笔**
- **文本**：底框填充 / 透明双模式，就地输入、失焦自动提交、双击重新编辑
- **数字标记**：①②③ 自动递增，分步说明利器
- **马赛克**：真·像素化（区域缩小 + 无插值放大）
- **画笔**：自由轨迹
- 拖动移动任意标注（箭头/画笔轨迹整体平移）、右键删除、⌘Z/⌘⇧Z 撤销重做
- 候选条紧贴工具栏上方展开（输入法候选词式），每工具独立记忆上次设置

### 保存
- **复制到剪贴板**（默认，一键完成）
- **保存到固定路径**（可配置，PNG/JPG）
- 完成反馈 toast

### OCR
- Apple Vision 离线识别，中英文准确率优秀
- 编辑器内一键：渲染含标注成品 → 复制 → 弹出可编辑结果面板

### 设置
- **开机自启动**（SMAppService 登录项）
- **Dock 图标显示开关**（默认仅驻留菜单栏，可切换为同时显示在 Dock）
- 全局快捷键自定义（任何 App 前台响应，[KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)）
- 默认保存路径、图片格式、自动复制/自动保存开关、OCR 语言

菜单栏图标使用自管理 `NSStatusItem`（含 autosaveName）：系统"菜单栏项目"设置中的显示/移除/位置管理可正确生效与持久化。

## 构建

要求：Xcode 16+，macOS 14+。

```bash
git clone https://github.com/<你的用户名>/rShot.git
cd rShot
open rShot.xcodeproj   # ⌘R 运行
```

或命令行：

```bash
xcodebuild -project rShot.xcodeproj -scheme rShot -configuration Debug build
```

首次运行需在「系统设置 → 隐私与安全性 → 屏幕录制」中授权 rShot。

## 测试

21 个单元测试覆盖撤销栈、标注文档、坐标布局、马赛克渲染、文件保存、剪贴板与 OCR 模型：

```bash
xcodebuild test -project rShot.xcodeproj -scheme rShot -destination 'platform=macOS'
```

## 打安装包（DMG）

```bash
./scripts/build-dmg.sh
# 产物：dist/rShot-<版本>.dmg（通用二进制，arm64 + x86_64）
```

挂载 DMG，把 rShot 拖入 Applications 即完成安装。未公证的 App 首次打开：右键 → 打开（或在系统设置中允许）。

## 技术栈

| 层 | 方案 |
|---|---|
| UI | Swift + SwiftUI（MenuBarExtra / 原位标注覆盖层）|
| 窗口管理 | AppKit NSPanel（KeyablePanel / nonactivating）|
| 截屏 | CGWindowListCreateImage 冻结帧 + 选区裁剪 |
| OCR | Vision VNRecognizeTextRequest |
| 全局热键 | KeyboardShortcuts（SPM）|
| 渲染输出 | SwiftUI ImageRenderer（所见即所得）|

架构参考了 [macshot](https://github.com/sw33tLie/macshot) 的 overlay 窗口管理实践。

## 项目结构

```
rShot/
├── rShotApp.swift        # 入口：MenuBarExtra + Settings
├── App/                  # 状态机 / 全局热键 / Toast
├── Capture/              # 截屏引擎 / 覆盖层（框选+原位标注）/ 窗口识别
├── Annotation/           # 标注模型 / 文档 / 画布 / 工具栏 / 马赛克
├── OCR/                  # Vision 封装 / 结果面板
├── Output/               # 剪贴板 / 文件保存
├── Settings/             # 设置窗
└── rShotTests/           # XCTest 单元测试
docs/                     # 产品需求（PRD）/ 设计指导 / 设计系统
scripts/                  # 图标生成 / DMG 打包
```

## License

MIT
