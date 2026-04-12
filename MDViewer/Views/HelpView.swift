import SwiftUI

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("help.title")
                        .font(.largeTitle).bold()
                    Text("help.subtitle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 4)

                Divider()

                HelpSection(icon: "doc.badge.plus", title: String(localized: "help.section.openFile")) {
                    HelpRow(shortcut: "⌘O",        desc: String(localized: "help.openFile.picker"))
                    HelpRow(shortcut: "⌘N",        desc: String(localized: "help.openFile.new"))
                    HelpRow(shortcut: String(localized: "help.openFile.shortcut.drag"),   desc: String(localized: "help.openFile.drag"))
                    HelpRow(shortcut: String(localized: "help.openFile.shortcut.finder"), desc: String(localized: "help.openFile.finder"))
                    HelpRow(shortcut: String(localized: "help.openFile.shortcut.recent"), desc: String(localized: "help.openFile.recent"))
                }

                HelpSection(icon: "rectangle.split.2x1", title: String(localized: "help.section.viewMode")) {
                    HelpRow(shortcut: "⌘1",  desc: String(localized: "help.viewMode.editor"))
                    HelpRow(shortcut: "⌘2",  desc: String(localized: "help.viewMode.split"))
                    HelpRow(shortcut: "⌘3",  desc: String(localized: "help.viewMode.viewer"))
                    HelpRow(shortcut: String(localized: "help.viewMode.shortcut.toolbar"), desc: String(localized: "help.viewMode.toolbar"))
                }

                HelpSection(icon: "arrow.left.arrow.right", title: String(localized: "help.section.splitSync")) {
                    HelpRow(shortcut: String(localized: "help.splitSync.shortcut.cursor"),   desc: String(localized: "help.splitSync.cursor"))
                    HelpRow(shortcut: String(localized: "help.splitSync.shortcut.vertical"), desc: String(localized: "help.splitSync.vertical"))
                    HelpRow(shortcut: String(localized: "help.splitSync.shortcut.anchor"),   desc: String(localized: "help.splitSync.anchor"))
                }

                HelpSection(icon: "square.and.pencil", title: String(localized: "help.section.editSave")) {
                    HelpRow(shortcut: "⌘S",   desc: String(localized: "help.editSave.save"))
                    HelpRow(shortcut: "⌘⇧S", desc: String(localized: "help.editSave.saveAs"))
                    HelpRow(shortcut: "⌘F",   desc: String(localized: "help.editSave.find"))
                    HelpRow(shortcut: String(localized: "help.editSave.shortcut.unsaved"), desc: String(localized: "help.editSave.unsaved"))
                }

                HelpSection(icon: "folder", title: String(localized: "help.section.folderSidebar")) {
                    HelpRow(shortcut: "⌘⇧O",  desc: String(localized: "help.folderSidebar.open"))
                    HelpRow(shortcut: String(localized: "help.folderSidebar.shortcut.button"),     desc: String(localized: "help.folderSidebar.button"))
                    HelpRow(shortcut: String(localized: "help.folderSidebar.shortcut.hierarchy"), desc: String(localized: "help.folderSidebar.hierarchy"))
                }

                HelpSection(icon: "list.bullet.indent", title: String(localized: "help.section.outline")) {
                    HelpRow(shortcut: String(localized: "help.outline.shortcut.mode"),  desc: String(localized: "help.outline.mode"))
                    HelpRow(shortcut: String(localized: "help.outline.shortcut.click"), desc: String(localized: "help.outline.click"))
                    HelpRow(shortcut: "H1–H6",   desc: String(localized: "help.outline.levels"))
                }

                HelpSection(icon: "magnifyingglass", title: String(localized: "help.section.zoom")) {
                    HelpRow(shortcut: "⌘=",  desc: String(localized: "help.zoom.in"))
                    HelpRow(shortcut: "⌘-",  desc: String(localized: "help.zoom.out"))
                    HelpRow(shortcut: "⌘0",  desc: String(localized: "help.zoom.reset"))
                    HelpRow(shortcut: String(localized: "help.zoom.shortcut.range"), desc: String(localized: "help.zoom.range"))
                }

                HelpSection(icon: "arrow.down.doc", title: String(localized: "help.section.export")) {
                    HelpRow(shortcut: "⌘E",   desc: String(localized: "help.export.pdf"))
                    HelpRow(shortcut: "⌘⇧E",  desc: String(localized: "help.export.html"))
                }

                HelpSection(icon: "paintpalette", title: String(localized: "help.section.theme")) {
                    HelpRow(shortcut: "⌘,",     desc: String(localized: "help.theme.prefs"))
                    HelpRow(shortcut: String(localized: "help.theme.shortcut.preview"), desc: String(localized: "help.theme.preview"))
                    HelpRow(shortcut: String(localized: "help.theme.shortcut.editor"),  desc: String(localized: "help.theme.editor"))
                }

                HelpSection(icon: "macwindow.on.rectangle", title: String(localized: "help.section.multiWindow")) {
                    HelpRow(shortcut: "⌘N",  desc: String(localized: "help.multiWindow.new"))
                    HelpRow(shortcut: String(localized: "help.multiWindow.shortcut.open"),  desc: String(localized: "help.multiWindow.open"))
                    HelpRow(shortcut: String(localized: "help.multiWindow.shortcut.reuse"), desc: String(localized: "help.multiWindow.reuse"))
                }

                Divider()

                Text("help.footer")
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
