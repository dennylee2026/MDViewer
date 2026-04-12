import SwiftUI
import WebKit

struct OutlineView: View {
    @EnvironmentObject var appState: AppState
    let webView: WKWebView?

    var body: some View {
        Group {
            if appState.headings.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text(appState.fileURL == nil ? "outline.noFile" : "outline.noHeadings")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(appState.headings) { heading in
                            HeadingRow(heading: heading) {
                                scrollTo(heading)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(minWidth: 180)
    }

    private func scrollTo(_ heading: HeadingItem) {
        webView?.evaluateJavaScript(
            "scrollToHeading(\(heading.index))",
            completionHandler: nil
        )
    }
}

private struct HeadingRow: View {
    let heading: HeadingItem
    let onTap: () -> Void

    private var indent: CGFloat { CGFloat((heading.level - 1) * 10) }

    private var labelColor: Color {
        switch heading.level {
        case 1, 2: return Color.primary
        default: return Color(nsColor: .labelColor).opacity(0.55)
        }
    }

    private var fontSize: CGFloat {
        switch heading.level {
        case 1: return 17
        case 2: return 16
        case 3: return 15
        default: return 14
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(heading.level == 1 ? Color(nsColor: .separatorColor) : Color.clear)
                    .frame(width: 3)
                Text(heading.text)
                    .font(.system(size: fontSize, weight: .regular))
                    .foregroundStyle(labelColor)
                    .lineLimit(2)
                    .padding(.leading, indent + 10)
                    .padding(.trailing, 8)
                    .padding(.vertical, 5)
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .hoverEffect()
    }
}

// MARK: - Hover highlight

private extension View {
    func hoverEffect() -> some View {
        modifier(HoverHighlight())
    }
}

private struct HoverHighlight: ViewModifier {
    @State private var hovered = false

    func body(content: Content) -> some View {
        content
            .background(hovered ? Color.primary.opacity(0.07) : Color.clear)
            .onHover { hovered = $0 }
    }
}
