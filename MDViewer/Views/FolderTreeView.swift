import SwiftUI

struct FolderTreeView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(appState.folderURL?.lastPathComponent ?? "文件夹")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if appState.folderItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "folder")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text("无 Markdown 文件")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(appState.folderItems, children: \.children) { item in
                    HStack(spacing: 6) {
                        Image(systemName: item.isDirectory ? "folder.fill" : "doc.text")
                            .font(.system(size: 12))
                            .foregroundStyle(item.isDirectory ? Color.orange : Color.secondary)
                        Text(item.name)
                            .font(.system(size: 12))
                            .lineLimit(1)
                            .foregroundStyle(appState.fileURL == item.url ? Color.accentColor : Color.primary)
                            .fontWeight(appState.fileURL == item.url ? .semibold : .regular)
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if !item.isDirectory { appState.open(url: item.url) }
                    }
                }
                .listStyle(.sidebar)
            }
        }
    }
}
