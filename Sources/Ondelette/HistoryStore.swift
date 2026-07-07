import Foundation

struct DictationEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    let raw: String
    let final: String
    /// Durée de l'enregistrement en secondes (absente sur les anciennes entrées).
    let duration: TimeInterval?
    /// App dans laquelle le texte a été collé.
    let app: String?

    var wordCount: Int {
        final.split(whereSeparator: \.isWhitespace).count
    }
}

/// Historique des dictées, persistant (JSON dans Application Support).
@MainActor
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    @Published private(set) var entries: [DictationEntry] = []

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Ondelette", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.json")
    }()

    private init() {
        load()
    }

    func add(raw: String, final: String, duration: TimeInterval? = nil, app: String? = nil) {
        entries.insert(
            DictationEntry(
                id: UUID(), date: Date(), raw: raw, final: final,
                duration: duration, app: app),
            at: 0)
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
        entries.reduce(0) { $0 + $1.wordCount }
    }

    var todayWords: Int {
        let calendar = Calendar.current
        return entries
            .filter { calendar.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.wordCount }
    }

    /// Vitesse de frappe moyenne au clavier, base de l'estimation du temps gagné.
    static let typingWPM = 40.0

    private var timedEntries: [DictationEntry] {
        entries.filter { ($0.duration ?? 0) > 1 }
    }

    /// Vitesse de dictée réelle (mots par minute), sur les entrées horodatées.
    var wordsPerMinute: Int {
        let timed = timedEntries
        let seconds = timed.reduce(0.0) { $0 + ($1.duration ?? 0) }
        guard seconds > 15 else { return 0 }
        let words = timed.reduce(0) { $0 + $1.wordCount }
        return Int((Double(words) / seconds * 60).rounded())
    }

    /// Multiplicateur de vitesse vs frappe au clavier (~40 mots/min).
    var speedMultiplier: Double {
        guard wordsPerMinute > 0 else { return 0 }
        return Double(wordsPerMinute) / Self.typingWPM
    }

    /// Temps gagné estimé vs taper au clavier, en secondes.
    var timeSavedSeconds: TimeInterval {
        let timed = timedEntries
        let dictated = timed.reduce(0.0) { $0 + ($1.duration ?? 0) }
        let words = timed.reduce(0) { $0 + $1.wordCount }
        let typingTime = Double(words) / Self.typingWPM * 60
        return max(0, typingTime - dictated)
    }

    /// Jours consécutifs avec au moins une dictée (série se terminant
    /// aujourd'hui, ou hier si la journée ne fait que commencer).
    var streakDays: Int {
        let calendar = Calendar.current
        let activeDays = Set(entries.map { calendar.startOfDay(for: $0.date) })
        guard !activeDays.isEmpty else { return 0 }

        var day = calendar.startOfDay(for: Date())
        if !activeDays.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day),
                  activeDays.contains(yesterday)
            else { return 0 }
            day = yesterday
        }
        var streak = 0
        while activeDays.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
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
