import Foundation
import CoreGraphics
import SwiftUI

enum CorrectionStyle: String, CaseIterable, Identifiable {
    case light
    case rewrite
    case off

    var id: String { rawValue }

    var label: String {
        switch self {
        case .light: return "Nettoyage léger (ponctuation, hésitations)"
        case .rewrite: return "Reformulation propre"
        case .off: return "Aucune correction (texte brut)"
        }
    }
}

enum TranscriptionEngine: String, CaseIterable, Identifiable {
    case whisper
    case parakeet

    var id: String { rawValue }

    var label: String {
        switch self {
        case .whisper: return "Whisper large-v3 turbo (précision, recommandé)"
        case .parakeet: return "Parakeet V3 (ultra rapide)"
        }
    }
}

enum HotkeyChoice: String, CaseIterable, Identifiable {
    case rightOption
    case rightCommand
    case fn

    var id: String { rawValue }

    var label: String {
        switch self {
        case .rightOption: return "⌥ Option droite"
        case .rightCommand: return "⌘ Commande droite"
        case .fn: return "🌐 Fn"
        }
    }

    var shortLabel: String {
        switch self {
        case .rightOption: return "⌥ droite"
        case .rightCommand: return "⌘ droite"
        case .fn: return "Fn"
        }
    }

    var keyCode: Int64 {
        switch self {
        case .rightOption: return 61
        case .rightCommand: return 54
        case .fn: return 63
        }
    }

    var flagMask: CGEventFlags {
        switch self {
        case .rightOption: return .maskAlternate
        case .rightCommand: return .maskCommand
        case .fn: return .maskSecondaryFn
        }
    }
}

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    @Published var gptModel: String {
        didSet { defaults.set(gptModel, forKey: "gptModel") }
    }

    @Published var correctionStyle: CorrectionStyle {
        didSet { defaults.set(correctionStyle.rawValue, forKey: "correctionStyle") }
    }

    @Published var hotkey: HotkeyChoice {
        didSet { defaults.set(hotkey.rawValue, forKey: "hotkey") }
    }

    @Published var playSounds: Bool {
        didSet { defaults.set(playSounds, forKey: "playSounds") }
    }

    /// Coupe le son de sortie pendant l'enregistrement.
    @Published var muteWhileRecording: Bool {
        didSet { defaults.set(muteWhileRecording, forKey: "muteWhileRecording") }
    }

    /// Vocabulaire personnalisé (un terme par ligne ou séparés par des virgules) :
    /// prénoms, marques, jargon que le micro écorche.
    @Published var customVocabulary: String {
        didSet { defaults.set(customVocabulary, forKey: "customVocabulary") }
    }

    /// Termes nettoyés du vocabulaire personnalisé.
    var vocabularyTerms: [String] {
        customVocabulary
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    @Published var engine: TranscriptionEngine {
        didSet { defaults.set(engine.rawValue, forKey: "engine") }
    }

    /// UID CoreAudio du micro choisi ("" = micro système par défaut).
    @Published var micUID: String {
        didSet { defaults.set(micUID, forKey: "micUID") }
    }

    /// Code ISO de la langue dictée ("auto" = détection automatique).
    @Published var languageCode: String {
        didSet { defaults.set(languageCode, forKey: "languageCode") }
    }

    static let languageOptions: [(code: String, label: String)] = [
        ("auto", "Détection automatique"),
        ("fr", "Français"),
        ("en", "Anglais"),
        ("es", "Espagnol"),
        ("de", "Allemand"),
        ("it", "Italien"),
        ("pt", "Portugais"),
        ("nl", "Néerlandais"),
    ]

    private init() {
        gptModel = defaults.string(forKey: "gptModel") ?? "gpt-5.4-mini"
        correctionStyle = CorrectionStyle(rawValue: defaults.string(forKey: "correctionStyle") ?? "") ?? .light
        hotkey = HotkeyChoice(rawValue: defaults.string(forKey: "hotkey") ?? "") ?? .rightOption
        playSounds = defaults.object(forKey: "playSounds") as? Bool ?? true
        muteWhileRecording = defaults.object(forKey: "muteWhileRecording") as? Bool ?? true
        customVocabulary = defaults.string(forKey: "customVocabulary") ?? ""
        languageCode = defaults.string(forKey: "languageCode") ?? "fr"
        micUID = defaults.string(forKey: "micUID") ?? ""
        engine = TranscriptionEngine(rawValue: defaults.string(forKey: "engine") ?? "") ?? .whisper
    }
}
