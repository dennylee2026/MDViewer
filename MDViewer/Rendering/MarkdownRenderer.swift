import Foundation

enum MarkdownRendererError: Error, LocalizedError {
    case unreadableFile(URL)

    var errorDescription: String? {
        switch self {
        case .unreadableFile(let url):
            return "Cannot read file: \(url.lastPathComponent)"
        }
    }
}

struct MarkdownRenderer {
    static func load(from url: URL) throws -> String {
        if let content = try? String(contentsOf: url, encoding: .utf8) {
            return content
        }
        if let content = try? String(contentsOf: url, encoding: .isoLatin1) {
            return content
        }
        throw MarkdownRendererError.unreadableFile(url)
    }
}
