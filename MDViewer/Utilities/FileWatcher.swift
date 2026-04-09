import Foundation

final class FileWatcher {
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1

    func watch(url: URL, onChange: @escaping () -> Void) {
        stop()
        fileDescriptor = open(url.path, O_EVTONLY)
        guard fileDescriptor != -1 else { return }

        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )
        source?.setEventHandler(handler: onChange)
        source?.setCancelHandler { [weak self] in
            guard let self, self.fileDescriptor != -1 else { return }
            close(self.fileDescriptor)
            self.fileDescriptor = -1
        }
        source?.resume()
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    deinit {
        stop()
    }
}
