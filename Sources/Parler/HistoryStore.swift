import Foundation

struct DictationEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    let raw: String
    let final: String
}

/// Historique des dictées, persistant (JSON dans Application Support).
@MainActor
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    @Published private(set) var entries: [DictationEntry] = []

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Parler", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.json")
    }()

    private init() {
        load()
    }

    func add(raw: String, final: String) {
        entries.insert(DictationEntry(id: UUID(), date: Date(), raw: raw, final: final), at: 0)
        if entries.count > 200 {
            entries.removeLast(entries.count - 200)
        }
        save()
    }

    func remove(_ entry: DictationEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    func clear() {
        entries.removeAll()
        save()
    }

    // MARK: - Statistiques

    var totalCount: Int { entries.count }

    var totalWords: Int {
        entries.reduce(0) { $0 + $1.final.split(whereSeparator: \.isWhitespace).count }
    }

    var todayWords: Int {
        let calendar = Calendar.current
        return entries
            .filter { calendar.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.final.split(whereSeparator: \.isWhitespace).count }
    }

    // MARK: - Persistance

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([DictationEntry].self, from: data)
        else { return }
        entries = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
