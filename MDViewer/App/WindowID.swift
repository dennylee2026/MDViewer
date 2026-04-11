import Foundation

/// Uniquely identifies a window. Every instance has a distinct UUID so
/// SwiftUI always opens a *new* window rather than reusing an existing one.
struct WindowID: Codable, Hashable {
    let id: UUID
    let fileURL: URL?

    static func empty() -> WindowID { WindowID(id: UUID(), fileURL: nil) }
    static func forFile(_ url: URL) -> WindowID { WindowID(id: UUID(), fileURL: url) }
}
