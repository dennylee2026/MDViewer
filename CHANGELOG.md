# Changelog

All notable changes to MDViewer will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
