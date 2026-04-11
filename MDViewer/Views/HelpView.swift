import SwiftUI

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("MDViewer 使用指南")
                        .font(.largeTitle).bold()
                    Text("快速掌握 MDViewer 的全部功能")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 4)

                Divider()

                HelpSection(icon: "doc.badge.plus", title: "打开文件") {
                    HelpRow(shortcut: "⌘O",        desc: "通过文件选择器打开 .md 文件")
                    HelpRow(shortcut: "⌘N",        desc: "新建空白窗口")
                    HelpRow(shortcut: "拖拽",       desc: "将 .md 文件拖入窗口直接打开")
                    HelpRow(shortcut: "Finder",    desc: "双击 .md 文件在新窗口打开")
                    HelpRow(shortcut: "最近文件",   desc: "File > 打开最近文件，记录最近 10 条")
                }

                HelpSection(icon: "rectangle.split.2x1", title: "视图模式") {
                    HelpRow(shortcut: "⌘1",  desc: "编辑模式 — 纯编辑，无侧栏")
                    HelpRow(shortcut: "⌘2",  desc: "分栏模式 — 左侧编辑 + 右侧实时预览")
                    HelpRow(shortcut: "⌘3",  desc: "预览模式 — 纯预览 + 左侧目录大纲")
                    HelpRow(shortcut: "工具栏", desc: "点击工具栏中央的三段式按钮快速切换")
                }

                HelpSection(icon: "arrow.left.arrow.right", title: "分栏同步") {
                    HelpRow(shortcut: "点击光标",  desc: "在编辑区点击后，预览区自动滚动到对应位置")
                    HelpRow(shortcut: "垂直对齐",  desc: "预览区保持与光标相同的垂直比例，而非强制置顶")
                    HelpRow(shortcut: "标题锚点",  desc: "以最近标题为锚点计算位置，代码块不会导致偏移")
                }

                HelpSection(icon: "square.and.pencil", title: "编辑与保存") {
                    HelpRow(shortcut: "⌘S",   desc: "保存当前文件；新文件触发另存为对话框")
                    HelpRow(shortcut: "⌘⇧S", desc: "另存为，选择新路径保存")
                    HelpRow(shortcut: "⌘F",   desc: "查找 / 替换（编辑区内建 Find Bar）")
                    HelpRow(shortcut: "未保存指示", desc: "工具栏显示橙色「Unsaved」；保存后出现「Saved ✓」提示")
                }

                HelpSection(icon: "folder", title: "文件夹侧栏") {
                    HelpRow(shortcut: "⌘⇧O",  desc: "打开文件夹，在左侧显示所有 .md 文件")
                    HelpRow(shortcut: "侧栏按钮", desc: "工具栏左侧按钮随时展开 / 收起文件夹侧栏")
                    HelpRow(shortcut: "层级展开",  desc: "支持子目录递归展示，点击文件在当前窗口打开")
                }

                HelpSection(icon: "list.bullet.indent", title: "目录大纲") {
                    HelpRow(shortcut: "预览模式", desc: "切换至预览模式（⌘3）后左侧自动显示目录大纲")
                    HelpRow(shortcut: "点击跳转", desc: "点击任意标题，预览区平滑滚动到对应位置")
                    HelpRow(shortcut: "H1–H6",   desc: "支持六级标题层级缩进")
                }

                HelpSection(icon: "magnifyingglass", title: "缩放") {
                    HelpRow(shortcut: "⌘=",  desc: "放大（编辑区字号 + 预览区页面缩放同步）")
                    HelpRow(shortcut: "⌘-",  desc: "缩小")
                    HelpRow(shortcut: "⌘0",  desc: "恢复 100%；也可点击工具栏百分比数字")
                    HelpRow(shortcut: "范围",  desc: "50% – 300%")
                }

                HelpSection(icon: "arrow.down.doc", title: "导出") {
                    HelpRow(shortcut: "⌘E",   desc: "导出为 PDF — 基于当前渲染输出高保真 PDF")
                    HelpRow(shortcut: "⌘⇧E",  desc: "导出为 HTML — 内联主题 CSS，生成独立 .html 文件")
                }

                HelpSection(icon: "paintpalette", title: "主题与字体") {
                    HelpRow(shortcut: "⌘,",     desc: "打开偏好设置")
                    HelpRow(shortcut: "预览主题", desc: "跟随系统 / 始终明亮 / 始终暗色 / 复古纸张（Sepia）")
                    HelpRow(shortcut: "编辑器字体", desc: "SF Pro（默认）/ Menlo（等宽）/ Palatino（衬线）")
                }

                HelpSection(icon: "macwindow.on.rectangle", title: "多窗口") {
                    HelpRow(shortcut: "⌘N",  desc: "新建空白窗口")
                    HelpRow(shortcut: "打开文件", desc: "每个文件在独立窗口中打开，状态完全隔离")
                    HelpRow(shortcut: "空窗口复用", desc: "若当前窗口为空白未编辑，打开文件时直接复用该窗口")
                }

                Divider()

                Text("遇到问题？欢迎在 GitHub 提交 Issue 反馈。")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 8)
            }
            .padding(32)
        }
        .frame(width: 560, height: 620)
    }
}

// MARK: - Components

private struct HelpSection<Content: View>: View {
    let icon: String
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 6) {
                content()
            }
            .padding(.leading, 4)
        }
    }
}

private struct HelpRow: View {
    let shortcut: String
    let desc: String

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(shortcut)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)
            Text(desc)
                .font(.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
