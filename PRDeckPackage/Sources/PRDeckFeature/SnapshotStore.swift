import Foundation

struct SnapshotStore {
    private let store: PersistentStore<[PRItem]>

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.store = .init(fileURL: fileURL)
        } else {
            self.store = .init(fileName: "snapshot.json")
        }
    }

    func loadSnapshot() -> [PRItem]? {
        store.load()
    }

    func saveSnapshot(_ items: [PRItem]) {
        store.save(items)
    }
}

extension JSONDecoder {
    /// Returns a fresh decoder per call to avoid shared mutable state across tasks.
    static var prdeck: JSONDecoder {
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
    }
}

extension JSONEncoder {
    /// Returns a fresh encoder per call to avoid shared mutable state across tasks.
    static var prdeck: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            var container = encoder.singleValueContainer()
            try container.encode(formatter.string(from: date))
        }
        return encoder
    }
}
