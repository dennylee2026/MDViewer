import Foundation
import AppKit
import Combine

final class StyleManager: ObservableObject {
    static let shared = StyleManager()

    @Published private(set) var stylesFile: StylesFile
    @Published private(set) var activeStyle: MarkdownStyle

    private let fileWatcher = FileWatcher()
    private var isRestoring = false
    private var appearanceObserver: NSKeyValueObservation?

    private init() {
        let file = StylesFile.load()
        stylesFile = file
        activeStyle = file.resolvedEffectiveStyle()
    }

    func setup() {
        // Ensure config file exists on disk
        if !FileManager.default.fileExists(atPath: StylesFile.configURL.path) {
            stylesFile.save()
        }
        // Watch for changes
        fileWatcher.watch(url: StylesFile.configURL) { [weak self] in
            self?.reload()
        }
        // Follow system dark/light mode transitions
        appearanceObserver = NSApp.observe(\.effectiveAppearance) { [weak self] _, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.activeStyle = self.stylesFile.resolvedEffectiveStyle()
            }
        }
    }

    /// Activate a style by name and persist the choice.
    func activate(_ name: String) {
        guard stylesFile.styles.contains(where: { $0.name == name }) else { return }
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        if isDark {
            stylesFile.darkActiveStyle = name
        } else {
            stylesFile.activeStyle = name
        }
        activeStyle = stylesFile.resolvedEffectiveStyle()
        stylesFile.save()
    }

    /// Called by FileWatcher when styles.json changes on disk.
    private func reload() {
        guard !isRestoring else { return }
        let url = StylesFile.configURL
        guard let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(StylesFile.self, from: data)
        else {
            // Corrupt file — restore defaults
            restoreDefaults()
            return
        }
        DispatchQueue.main.async {
            self.stylesFile = file
            self.activeStyle = file.resolvedEffectiveStyle()
        }
    }

    private func restoreDefaults() {
        isRestoring = true
        StylesFile.systemDefaults.save()
        DispatchQueue.main.async {
            self.stylesFile = StylesFile.systemDefaults
            self.activeStyle = StylesFile.systemDefaults.resolvedEffectiveStyle()
            self.isRestoring = false
        }
    }

    func openConfigFile() {
        NSWorkspace.shared.open(StylesFile.configURL)
    }
}
