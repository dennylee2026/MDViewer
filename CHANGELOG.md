# Changelog

All notable changes to MDViewer will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.9.1] - 2026-04-11

### Fixed
- 修复窗口高度自动适配的竞态条件：将调整逻辑从 `onChange(of: fileURL)` 移至 `onAppear`，延迟增至 0.2 s，并加入 `NSApplication.shared.keyWindow` 兜底，确保窗口引用在 SwiftUI 渲染周期完成前可靠获取

## [1.9.0] - 2026-04-10

### Added
- 打开文件时窗口高度自动适配内容长度（420 + 行数 × 13，限定在 500 px 至屏幕可视高度的 88%），向上展开、底边锚定，并限制在屏幕可视区内

## [1.8.1] - 2026-04-10

### Fixed
- 修复预览区底部留白失效的问题：将 `height: 100%` 改为 `min-height: 100vh`，使 `padding-bottom: 80px` 正确参与滚动计算

## [1.8.0] - 2026-04-10

### Added
- 多窗口支持：每个文件在独立窗口中打开，窗口间状态完全隔离
- ⌘N 打开新空白窗口；⌘O / 工具栏"打开" / Finder 双击均在新窗口中打开文件
- 最近文件点击也在新窗口打开
- 使用 `@FocusedObject` 确保菜单命令始终作用于当前聚焦窗口
- 工具栏编辑状态提示：有未保存内容时显示橙色 "Unsaved" 文字，平滑淡入淡出
- 保存后顶部滑入 "Saved ✓" 胶囊提示，2 秒后自动消失

## [1.7.0] - 2026-04-10

### Added
- 自定义主题：偏好设置（⌘,）中可选预览主题（跟随系统 / 始终明亮 / 始终暗色 / 复古纸张 Sepia）
- 自定义编辑器字体：偏好设置中可选 SF Pro / Menlo / Palatino
- 目录树侧栏：File > 打开文件夹（⌘⇧O），在左侧显示文件夹内所有 `.md` 文件，支持层级展开，工具栏按钮可随时收起

### Fixed
- 预览区滚动到末尾时增加底部留白（padding-bottom 40px → 80px），阅读体验更舒适

## [1.6.0] - 2026-04-10

### Added
- 导出为 HTML：内联主题 CSS，生成独立 `.html` 文件（File > 导出为 HTML… / ⌘E）
- 导出为 PDF：基于 WKWebView 当前渲染，输出 PDF 文件（File > 导出为 PDF… / ⌘⇧E）
- 最近文件菜单：File > 打开最近文件，记录最近 10 条，支持一键清除

## [1.5.4] - 2026-04-10

### Fixed
- 彻底修复输入法兼容性：MarkdownHighlighter 直接在 `textStorage(_:didProcessEditing:)` 内同步调用 `textView.hasMarkedText()`，在正确的时机跳过高亮，不再破坏 IME 合成状态

## [1.5.3] - 2026-04-10

### Fixed
- 彻底修复输入法兼容性：语法高亮器在 IME 合成期间不再调用 `setAttributes(range: full)`，避免覆盖输入法写入的内部属性，防止已确认汉字丢失及界面异常闪烁

## [1.5.2] - 2026-04-10

### Fixed
- 修复编辑区与中文 / 日文输入法不兼容的问题：合成期间不再触发 SwiftUI 刷新，候选字不会被打断
- 修复每次按键都重置字体排版的问题（改用字号比较而非 NSFont 对象比较）

## [1.5.1] - 2026-04-10

### Fixed
- 预览区行间距调整为 1.5
- 编辑区移除额外段落间距，`lineHeightMultiple = 1.25` 视觉效果准确
- 修复编辑器中 `**加粗**` 文字被同时渲染为粗体+斜体的问题（斜体正则在 `*` 两侧加断言，不再误匹配 `**` 标记）
- 加粗与标题字形改用继承 PingFang SC 级联的字体描述符，中文字体渲染与正文保持一致

## [1.5.0] - 2026-04-10

### Changed
- 编辑区与预览区正文默认字号由 14 调整为 18（缩放功能不受影响）

## [1.4.1] - 2026-04-10

### Fixed
- 光标落在编辑区时，预览区正确滚动到对应位置（不再强制跳回顶部）
- 修复每次按键触发重新渲染后 `window.scrollTo(0,0)` 覆盖光标同步滚动的竞态问题
- 改用 TreeWalker 遍历所有文本节点，粗体 / 斜体 / 行内代码内的文字也能正确匹配
- 修复 `JSONSerialization` 对纯字符串返回 nil 导致 `scrollToEditorText` 从未被调用的问题

## [1.4.0] - 2026-04-10

### Added
- 编辑区中文 / 日文支持：行高 1.6 倍、段落间距，阅读体验舒适
- IME 输入法合成文字样式（下划线 + 淡色背景），候选字清晰可辨
- `typingAttributes` 与 `defaultParagraphStyle` 保持一致，新输入文字不突变
- 禁用语法检查，避免对中日文误报

### Fixed
- 语法高亮扫描后不再重置段落样式，行距保持稳定

## [1.3.0] - 2026-04-10

### Added
- 缩放同时作用于编辑区和预览区（字号 / pageZoom 联动）
- 光标位置同步：光标落在编辑区某段落时，预览区自动滚动到对应标题

### Changed
- 编辑区字体改为 Apple 系统字体（SF Pro）14pt，语法高亮字号随之缩放
- 移除编辑器↔预览滚动位置联动，两侧独立滚动

## [1.2.1] - 2026-04-10

### Fixed
- 修复 MarkdownHighlighter 中 `var` 应为 `let` 的编译警告
- 修复 AppDelegate `reloadFromDisk` 中未使用变量的编译警告

## [1.2.0] - 2026-04-09

### Added
- 编辑器 Markdown 语法高亮：标题 Google 四色、粗体、斜体、行内代码、链接、删除线、引用块、代码块
- 编辑器行号显示（LineNumberRulerView）
- 编辑器与预览区滚动同步：滚动编辑器，预览自动跟随相同比例
- ⌘F 查找替换（NSTextView 内建 Find Bar）

## [1.1.0] - 2026-04-09

### Added
- 目录大纲侧栏：基于标题层级自动生成，点击跳转对应位置
- 标题颜色与正文主题保持一致（Google 四色）
- 侧栏支持 H1–H6 层级缩进
- 内置 Markdown 编辑器（NSTextView，等宽字体，软换行）
- 三种视图模式：编辑（⌘1）/ 分栏（⌘2）/ 预览（⌘3）
- 启动默认分栏模式；打开文件自动切换预览模式
- 编辑模式和分栏模式下隐藏大纲侧栏
- ⌘N 新建文件，⌘S 保存，⌘⇧S 另存为
- 标题栏 `•` 未保存状态指示；关闭前弹确认对话框
- 页面缩放：工具栏 +/- 按钮，⌘=/⌘-/⌘0，范围 50%–300%

## [1.0.0] - 2026-04-09

### Added
- 打开并渲染单个 `.md` 文件，排版美观可读
- 明亮 / 暗色主题，跟随系统外观自动切换
- 标题 Google 品牌四色循环（H1 蓝 / H2 红 / H3 黄 / H4 绿）
- 代码块语法高亮（highlight.js）
- 图片自适应宽度
- 拖拽 `.md` 文件到窗口打开（欢迎页 & 已打开文件时均支持）
- File > Open…（⌘O）菜单命令
- Finder 双击 `.md` 文件直接在 MDViewer 打开
- 文件保存后自动刷新（FSEvents 监听）
