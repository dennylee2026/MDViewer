# Changelog

All notable changes to MDViewer will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.4.5] - 2026-04-12

### Fixed
- 手机 PDF / 手机长图右侧大面积空白：`#content` 容器继承了桌面样式的 `max-width: 860px`，导致内容区窄于 390pt 页面宽度；新增 `#content { max-width: 100%; width: 100%; margin/padding: 0 }` 覆盖，内容区填满全宽，左右留白完全对称

## [2.4.4] - 2026-04-12

### Fixed
- 手机 PDF 尾部内容被截断：
  - 初始布局等待从 0.5s 延长至 0.8s（28px 字号在 390pt 宽度下重排耗时更长）
  - `scrollHeight` 改用 `Math.max(body.scrollHeight, documentElement.scrollHeight)` 取最大值
  - 设置 webView 高度后再等 0.3s 并二次查询高度，取两次测量的最大值
  - 末尾追加 64pt 缓冲，防止最后一个元素的底部 padding/margin 被裁掉
  - `createPDF` 前额外等待 0.2s，确保最终帧完成渲染

## [2.4.3] - 2026-04-12

### Fixed
- 手机 PDF / 手机长图：表格和内联代码在窄列中溢出截断
  - `table`: 新增 `table-layout: fixed` 强制列宽按比例分配，不再按内容撑宽
  - `td, th`: 新增 `word-break: break-word` + `max-width: 0`，单元格内容强制换行
  - `code`（内联）: `white-space: normal` + `word-break: break-all`，内联代码可在窄列内换行
  - `pre code`: 覆盖上条，保持代码块 `white-space: pre-wrap` 行为不变

## [2.4.2] - 2026-04-12

### Fixed
- 手机 PDF / 手机长图中代码块右侧被截断：对 `pre` 元素强制 `white-space: pre-wrap` + `word-break: break-all` + `overflow: visible`，使长代码行在 390pt 宽度内自动换行而非溢出截断

### Changed
- 手机导出左右边距从 16px 增大至 22px，提升手机端正文阅读舒适度

## [2.4.1] - 2026-04-12

### Fixed
- 导出手机 PDF / 手机长图右侧仍被截断：根本原因是 WKWebView 由 SwiftUI AutoLayout 管理，直接设置 `frame` 会在下一次布局传递时被约束系统还原，导致 `createPDF` 执行时 webView 宽度已恢复为原始值，`config.rect.width=390` 仅截取了宽页面的左侧部分；修复方案：导出前先收集并停用所有约束、设置 `translatesAutoresizingMaskIntoConstraints = true`，确保 webView 在 390pt 宽度下正确重排，导出后完整恢复约束

## [2.4.0] - 2026-04-12

### Fixed
- 导出手机 PDF 和手机长图右侧内容被截断：根本原因是 `WKPDFConfiguration.rect` 截取的是当前 webView 的像素区域，若 webView 宽度大于 390pt 则右侧超出部分丢失；修复方式为在导出前临时将 webView 收窄至 390pt（`alphaValue=0` 隐藏过渡），导出完成后恢复原始尺寸
- 导出手机长图：改用 PDF-to-image 方案（PDFKit），完全避免 WKWebView 分块渲染截断问题，保证全文内容完整输出

## [2.3.9] - 2026-04-12

### Fixed
- 导出手机长图：改用分块拼接（tile-stitch）方案替代单次全高截图，彻底解决 WKWebView 分块渲染导致内容截断的问题；正确处理 Retina 分辨率，拼接完成后重置滚动位置
- 导出手机 PDF 字号在手机端仍太小：页面宽度改为 390pt，字体从 24px 调大至 28px，标题比例随之调整
- 导出手机 PDF 出现分页：使用 `WKPDFConfiguration.rect` 设置为文档实际高度，生成真正连续无分页的单页 PDF；并通过 CSS `page-break: avoid` 全局抑制所有分页符

## [2.3.8] - 2026-04-12

### Added
- 所有导出文件名末尾追加时间戳（格式：`yyyyMMddTHHmm`，如 `doc_20260412T0314.pdf`）

### Fixed
- 导出手机长图时窗体内容出现明显大小缩放：通过 `CATransaction.setDisableActions(true)` 抑制帧变化动画，同时将 webView `alphaValue` 置 0 使缩放过程不可见
- 导出手机长图偶发失败：将 webView 布局等待时间从 0.15s/0.1s 延长至 0.5s/0.5s，确保内容在较窄宽度下完成重排后再截图
- 全部导出中的手机长图现可正常生成

## [2.3.7] - 2026-04-12

### Added
- 工具栏新增导出下拉菜单（位于「打开文件」图标左侧），含四项：导出 PDF / 导出手机 PDF / 导出手机长图 / 全部导出
- 导出手机 PDF：与桌面 PDF 相同的连续无分页格式，叠加 18px 正文字号及配套标题字号 CSS
- 导出手机长图：应用与手机 PDF 相同的字号样式，以 390pt 宽截取全文高度 PNG（Retina 显示器自然输出 2× 分辨率）
- 全部导出：选择目标文件夹后一次性生成三个文件（桌面 PDF、手机 PDF、手机长图）

### Changed
- 菜单栏导出快捷键重新分配：⌘E = PDF，⌘⇧E = 手机 PDF，⌘⌥E = 手机长图；HTML 导出保留但取消快捷键

## [2.3.6] - 2026-04-12

### Changed
- README 移除截图占位符和中间冗余的语言链接

## [2.3.5] - 2026-04-12

### Changed
- README 顶部新增语言切换链接（English | 中文）

## [2.3.4] - 2026-04-12

### Changed
- 重写中英文 README：新增价值主张开场、「为什么选 MDViewer」利益陈述区块，样式系统作为差异化亮点单独成节，叙述从功能列表改为用户利益导向

## [2.3.3] - 2026-04-12

### Fixed
- 修复 Xcode 警告：AppCommands 中 4 处 Selector 字符串字面量替换为类型安全的 #selector(NSTextView.performTextFinderAction(_:))
- 新增 LSApplicationCategoryType（productivity）消除 App Category 缺失警告

## [2.3.2] - 2026-04-12

### Changed
- 将所有文档中对 Google 品牌颜色的直接引用替换为 GDS 四色，消除潜在侵权风险

## [2.3.1] - 2026-04-12

### Removed
- 移除 21 处垃圾代码：StyleTypes 中 9 个从未被读取的结构体字段、OutlineView 中孤立的 Color(hex:) 扩展、FileWatcher 中只写不读的 fileDescriptor 属性、EditorView 中无效的 no-op 计算块、两份 Localizable.strings 中旧主题系统遗留的 9 个 prefs.theme.*/prefs.font.* key

## [2.3.0] - 2026-04-12

### Added
- 样式选择系统：单一 `styles.json` 配置文件（位于 `~/Library/Application Support/MDViewer/`）定义多套样式，首次启动自动生成
- 内置三套样式：GDS-Style（GDS 四色配色，默认）、Dark（深色）、Sepia（复古纸张）
- 每套样式分别控制编辑区（`editorStyle`：字体/字号/行高/各元素高亮色）和显示区（`displayStyle`：完整 CSS，覆盖 H1–H6、段落、粗体、斜体、代码、引用、表格、链接等所有 Markdown 要素）
- 偏好设置新增样式选择器和「打开配置文件」按钮，支持文本编辑修改样式
- FileWatcher 实时监听 `styles.json` 变动，保存后立即生效，无需重启
- 配置文件损坏时自动从 app 内置 systemDefaults 写回恢复，无 .bak 文件

### Removed
- 移除旧版静态 CSS 文件（light.css、dark.css、sepia.css、hljs-light.css、hljs-dark.css）
- 移除 `switchTheme()` 旧主题切换逻辑，全部由 `applyCustomStyle()` 动态注入替代

## [2.2.3] - 2026-04-11

### Fixed
- 修复 App 图标在 Dock 中显示空白的问题：重新生成符合 iconutil 命名规范的完整图标集（10 个尺寸），修正 Assets.xcassets/AppIcon.appiconset/Contents.json 中重复文件名导致 actool 编译不完整的问题

## [2.2.2] - 2026-04-11

### Added
- 国际化支持：新增 `zh-Hans.lproj/Localizable.strings` 与 `en.lproj/Localizable.strings`，覆盖所有菜单、工具栏、提示、帮助页、偏好设置等 UI 字符串
- 系统语言自动切换：中文系统显示中文，英文系统显示英文，无需手动配置

## [2.2.1] - 2026-04-11

### Added
- 替换 App 图标：从 resource/app-icon-raw.png 生成全套 macOS 图标（16–1024px）

## [2.2.0] - 2026-04-11

### Fixed
- 修复多文件同时打开时第 3、5 个窗口高度不调整的问题：WindowFinder 加入最多 10 次 × 50ms 重试轮询，确保 nsWindow 在任何时序下都能正确捕获；WindowView 增加 needsResize 标记与 onChange(of: nsWindow) 兜底，彻底移除 keyWindow 回退

## [2.1.9] - 2026-04-11

### Fixed
- 多文件同时打开时，窗口高度调整改为顺序执行：每个文件间隔 0.45s 打开，确保前一个窗口的 resize 动画完成后再开始下一个

## [2.1.8] - 2026-04-11

### Changed
- 打开文件选择器（⌘O）支持多选：可同时选择多个 `.md` 文件，每个文件在独立窗口中打开

## [2.1.7] - 2026-04-11

### Added
- 分栏模式下点击右侧预览区，左侧编辑区同步滚动到对应位置并保持相同高度（基于标题锚点 + 节内比例反向映射）

### Fixed
- 将 `editorScrollTarget` 从 ContentView 的 `@State` 移至 AppState 的 `@Published`，解决 WKScriptMessageHandler 回调中 SwiftUI 视图未被正确失效的问题

## [2.1.6] - 2026-04-11

### Added
- 预览模式下目录大纲侧栏默认隐藏，打开新文件时自动重置为隐藏状态，用户可手动展开
- 点击预览区内的 `.md` / `.markdown` 超链接时弹出确认对话框，确认后通过 WindowCoordinator 打开对应文件（支持相对路径解析）

## [2.1.5] - 2026-04-11

### Changed
- 目录大纲字号提升（H1 17pt / H2 16pt / H3 15pt / H4+ 14pt），取消加粗，主标题黑色、次级标题改为深灰（labelColor × 0.55）
- 文件夹侧栏字号提升至 14pt，取消加粗，非活跃条目改为深灰

## [2.1.4] - 2026-04-11

### Added
- 查找与替换：⌘F 打开查找栏，⌘⌥F 打开查找替换栏，⌘G / ⌘⇧G 跳转下一个 / 上一个匹配项，基于 NSTextView 内建 NSTextFinder 实现

## [2.1.3] - 2026-04-11

### Fixed
- 修复拖拽打开文件的兼容性：`NSItemProvider` 在不同 macOS 版本返回 `Data` 或 `NSURL`，现在两种情况均可正确解析
- 拖拽文件改为经由 `WindowCoordinator` 打开，与 ⌘O 行为一致（空白窗口复用，否则新建窗口）
- 拖拽悬停时显示蓝色边框与淡蓝背景作为视觉反馈

## [2.1.2] - 2026-04-11

### Changed
- 移除无效代码：`openFilePicker`、`presentOpenPanel`、`newFile`、`doNewFile`、`guardUnsaved`（已被 WindowCoordinator 接管）及整个 `MarkdownRenderer.swift`（零引用）

## [2.1.1] - 2026-04-11

### Added
- 打开新窗口时继承上一次使用的缩放比例：`AppState` 初始化时从 UserDefaults 读取，每次缩放变化时自动写入

## [2.1.0] - 2026-04-11

### Added
- Help 菜单（⌘?）：内置使用指南，涵盖打开文件、视图模式、分栏同步、编辑与保存、文件夹侧栏、目录大纲、缩放、导出、主题与字体、多窗口共 9 个功能区块

### Fixed
- 将导出为 PDF（⌘E）与导出为 HTML（⌘⇧E）快捷键对调

## [2.0.1] - 2026-04-11

### Fixed
- 修复代码块后预览区滚动位置偏移的问题：改用标题锚点定位（光标 charOffset → 最近标题 + 节内比例），替代原来基于源码行数的线性映射，彻底消除代码块导致的累积偏差

## [2.0.0] - 2026-04-11

### Fixed
- 修复分栏模式下编辑区光标点击后预览区不滚动的问题：新增 `lineFraction`（光标行 / 总行数）参数，文字匹配失败时直接调用 `scrollToFraction` 保证预览区始终更新
- 修复重复文字始终定位到第一个匹配项的问题：JS 改为收集全部匹配块元素，选取文档位置比例最接近 `lineFraction` 的目标，而非盲取第一个
- 修复预览区光标同步位置错误（始终置顶）：将 `lineFraction` 传入 JS，使目标元素出现在预览区与光标在编辑区相同的垂直比例位置

## [1.9.6] - 2026-04-11

### Fixed
- 修复 `WindowFinder` 在视图更新期间直接写 `@Binding` 导致的 "Modifying state during view update" 警告：改用 `DispatchQueue.main.async` 推迟写操作至当前渲染周期结束后执行

## [1.9.5] - 2026-04-11

### Fixed
- 修复工具栏模式切换图标顶部对齐的问题：将 "Unsaved" 文字从 VStack 移出，改用 `.overlay` + `.offset` 悬浮定位，Picker 作为 ToolbarItem 根视图后系统自动垂直居中
- 修复打开文件面板导航问题：改为在 `AppState.open(url:)` 中记录最后打开的文件路径，覆盖所有打开路径（含 Finder、拖拽），面板读取时用 `deletingLastPathComponent()` 动态计算目录 URL，确保导航进入目录而非选中文件夹本身

## [1.9.4] - 2026-04-11

### Fixed
- 修复打开文件面板仍停在文件夹本身的问题：重建 `directoryURL` 时加入 `isDirectory: true`，NSOpenPanel 正确导航进入目录而非将其作为文件选中
- 修复复用空白窗口打开文件后窗口高度未调整的问题：将调整触发点从 `onAppear` 改为 `onChange(of: appState.fileURL)`，无论新窗口还是复用窗口，文件加载后均会触发高度适配

## [1.9.3] - 2026-04-11

### Fixed
- 修复打开文件面板默认停在上次文件夹本身的问题：改为将上次打开文件的所在目录写入 UserDefaults，面板打开时直接导航进入该目录，文件立即可见，无需再手动双击文件夹

## [1.9.2] - 2026-04-11

### Fixed
- 修复打开文件面板默认停在上次所在文件夹本身的问题：设置 `directoryURL` 为最近文件的所在目录，面板打开后直接展示该目录内的文件

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
- 编辑器 Markdown 语法高亮：标题 GDS 四色、粗体、斜体、行内代码、链接、删除线、引用块、代码块
- 编辑器行号显示（LineNumberRulerView）
- 编辑器与预览区滚动同步：滚动编辑器，预览自动跟随相同比例
- ⌘F 查找替换（NSTextView 内建 Find Bar）

## [1.1.0] - 2026-04-09

### Added
- 目录大纲侧栏：基于标题层级自动生成，点击跳转对应位置
- 标题颜色与正文主题保持一致（GDS 四色）
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
- 标题 GDS 四色循环（H1 蓝 / H2 红 / H3 黄 / H4 绿）
- 代码块语法高亮（highlight.js）
- 图片自适应宽度
- 拖拽 `.md` 文件到窗口打开（欢迎页 & 已打开文件时均支持）
- File > Open…（⌘O）菜单命令
- Finder 双击 `.md` 文件直接在 MDViewer 打开
- 文件保存后自动刷新（FSEvents 监听）
