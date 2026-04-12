import SwiftUI

struct FolderTreeView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(appState.folderURL?.lastPathComponent ?? String(localized: "sidebar.folder.default"))
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.primary)
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
                    Text("sidebar.folder.empty")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(appState.folderItems, children: \.children) { item in
                    HStack(spacing: 6) {
                        Image(systemName: item.isDirectory ? "folder.fill" : "doc.text")
                            .font(.system(size: 14))
                            .foregroundStyle(item.isDirectory ? Color.secondary : Color(nsColor: .tertiaryLabelColor))
                        Text(item.name)
                            .font(.system(size: 14))
                            .lineLimit(1)
                            .foregroundStyle(appState.fileURL == item.url ? Color.primary : Color(nsColor: .labelColor).opacity(0.55))
                            .fontWeight(.regular)
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
