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
                    Text(appState.fileURL == nil ? "No file open" : "No headings")
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
        case 1: return Color(hex: "#4285F4")
        case 2: return Color(hex: "#EA4335")
        case 3: return Color(hex: "#FBBC05")
        case 4: return Color(hex: "#34A853")
        case 5: return Color(hex: "#4285F4")
        default: return Color(hex: "#EA4335")
        }
    }

    private var fontSize: CGFloat {
        switch heading.level {
        case 1: return 13
        case 2: return 12
        default: return 11
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(heading.level == 1 ? labelColor : Color.clear)
                    .frame(width: 3)
                Text(heading.text)
                    .font(.system(size: fontSize))
                    .foregroundStyle(heading.level <= 2 ? labelColor : .primary)
                    .fontWeight(heading.level == 1 ? .semibold : .regular)
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

// MARK: - Color from hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
