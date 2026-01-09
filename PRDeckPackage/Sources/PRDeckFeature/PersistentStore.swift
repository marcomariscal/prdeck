import Foundation

struct PersistentStore<T: Codable> {
    private let fileURL: URL
    private let makeDecoder: () -> JSONDecoder
    private let makeEncoder: () -> JSONEncoder

    init(
        fileURL: URL,
        makeDecoder: @escaping () -> JSONDecoder = { .prdeck },
        makeEncoder: @escaping () -> JSONEncoder = { .prdeck }
    ) {
        self.fileURL = fileURL
        self.makeDecoder = makeDecoder
        self.makeEncoder = makeEncoder
    }

    init(
        fileName: String,
        directoryName: String = "PRDeck",
        makeDecoder: @escaping () -> JSONDecoder = { .prdeck },
        makeEncoder: @escaping () -> JSONEncoder = { .prdeck }
    ) {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let directory = (base ?? URL(fileURLWithPath: NSTemporaryDirectory()))
            .appendingPathComponent(directoryName, isDirectory: true)
        self.init(
            fileURL: directory.appendingPathComponent(fileName, isDirectory: false),
            makeDecoder: makeDecoder,
            makeEncoder: makeEncoder
        )
    }

    func load() -> T? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? makeDecoder().decode(T.self, from: data)
    }

    func save(_ value: T) {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try makeEncoder().encode(value)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            // Cache writes are best-effort.
        }
    }
}

