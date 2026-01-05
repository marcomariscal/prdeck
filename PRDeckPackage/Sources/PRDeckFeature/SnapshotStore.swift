import Foundation

struct SnapshotStore {
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
            return
        }

        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let directory = (base ?? URL(fileURLWithPath: NSTemporaryDirectory()))
            .appendingPathComponent("PRDeck", isDirectory: true)
        self.fileURL = directory.appendingPathComponent("snapshot.json", isDirectory: false)
    }

    func loadSnapshot() -> [PRItem]? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder.prdeck.decode([PRItem].self, from: data)
    }

    func saveSnapshot(_ items: [PRItem]) {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder.prdeck.encode(items)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            // Cache writes are best-effort.
        }
    }
}

extension JSONDecoder {
    static let prdeck: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)

            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: raw) { return date }

            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            if let date = plain.date(from: raw) { return date }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601 date: \(raw)")
        }
        return decoder
    }()
}

extension JSONEncoder {
    static let prdeck: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            var container = encoder.singleValueContainer()
            try container.encode(formatter.string(from: date))
        }
        return encoder
    }()
}
