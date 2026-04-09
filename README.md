# MDViewer

macOS 原生的 Markdown 阅读器，专注于排版美观和阅读体验。

<!-- Screenshot placeholder -->
> 截图待添加

## 特性

- 打开并美观渲染 `.md` / `.markdown` 文件
- 从 Finder 双击打开、拖拽打开
- 明亮 / 暗色主题，跟随系统外观自动切换
- 标题使用 Google 品牌四色：H1 蓝、H2 红、H3 黄、H4 绿
- 代码块语法高亮（highlight.js）
- 图片自适应宽度

## 构建要求

- macOS 14.0+
- Xcode 15+

## 构建方式

```bash
# 克隆仓库
git clone https://github.com/dennylee2026/MDViewer.git
cd MDViewer

# 生成 Xcode 项目（首次或 project.yml 修改后需运行）
brew install xcodegen
xcodegen generate

# 用 Xcode 打开并构建
open MDViewer.xcodeproj
```

## 使用方法

- 启动 App 后点击「Open Markdown File…」选择 `.md` 文件
- 或从 Finder 拖拽 `.md` 文件到窗口
- 通过 **File > Open…**（⌘O）打开文件
- 系统切换深色/浅色模式时，阅读主题自动跟随

## 开发

日常开发在 `dev` 分支进行，功能稳定后合并到 `main`。
