import AppKit

@main
struct OndeletteMain {
    @MainActor
    static func main() {
        MigrationFromParler.runIfNeeded()
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

/// L'app s'appelait « Parler » (bundle com.charles.parler) : on récupère
/// les réglages et l'historique de l'ancienne identité, une seule fois.
enum MigrationFromParler {
    static func runIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "migratedFromParler") else { return }

        if let old = UserDefaults.standard.persistentDomain(forName: "com.charles.parler") {
            for (key, value) in old where defaults.object(forKey: key) == nil {
                defaults.set(value, forKey: key)
            }
        }

        let fm = FileManager.default
        let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let oldDir = support.appendingPathComponent("Parler", isDirectory: true)
        let newDir = support.appendingPathComponent("Ondelette", isDirectory: true)
        if fm.fileExists(atPath: oldDir.path), !fm.fileExists(atPath: newDir.path) {
            try? fm.moveItem(at: oldDir, to: newDir)
        }

        defaults.set(true, forKey: "migratedFromParler")
    }
}
