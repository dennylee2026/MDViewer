import Foundation

final class FileWatcher {
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var watchedURL: URL?
    private var onChange: (() -> Void)?

    func watch(url: URL, onChange: @escaping () -> Void) {
        self.watchedURL = url
        self.onChange = onChange
        startWatching(url: url)
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    private func startWatching(url: URL) {
        source?.cancel()
        source = nil

        let fd = open(url.path, O_EVTONLY)
        guard fd != -1 else { return }
        fileDescriptor = fd

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete, .attrib],
            queue: .main
        )

        src.setEventHandler { [weak self] in
            guard let self else { return }
            let flags = src.data
            self.onChange?()
            // Atomic-save editors replace the file via rename/delete;
            // re-watch the path so we keep receiving events.
            if flags.contains(.rename) || flags.contains(.delete) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    guard let url = self.watchedURL else { return }
                    self.startWatching(url: url)
                }
            }
        }

        src.setCancelHandler {
            close(fd)
        }

        src.resume()
        source = src
    }

    deinit {
        stop()
    }
}
