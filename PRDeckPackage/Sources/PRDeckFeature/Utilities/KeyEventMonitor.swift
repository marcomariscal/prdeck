import AppKit

final class KeyEventMonitor {
    private var monitor: Any?
    private let handler: (NSEvent) -> Bool

    init(handler: @escaping (NSEvent) -> Bool) {
        self.handler = handler
    }

    func start() {
        stop()
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [handler] event in
            if handler(event) { return nil }
            return event
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    deinit {
        stop()
    }
}

