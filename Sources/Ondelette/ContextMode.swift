import AppKit
import SwiftUI

/// Contexte de destination du texte dicté, déduit de l'app frontale.
/// La correction GPT adapte son style en conséquence (façon Wispr Flow).
enum AppContext: String {
    case mail
    case chat
    case code
    case writing
    case ai
    case standard

    /// Nom affiché dans le panneau Modes.
    var displayName: String {
        switch self {
        case .mail: return "E-mail"
        case .chat: return "Messagerie"
        case .code: return "Code & terminal"
        case .writing: return "Notes & rédaction"
        case .ai: return "Prompt IA"
        case .standard: return "Standard"
        }
    }

    /// Description du comportement, affichée dans le panneau Modes.
    var summary: String {
        switch self {
        case .mail:
            return "Ton professionnel et soigné, paragraphes, formules de politesse propres."
        case .chat:
            return "Décontracté et concis : garde le ton oral, n'ajoute aucune formule."
        case .code:
            return "Correction minimale : termes techniques intacts, pas de ponctuation imposée, « tiret m » → -m."
        case .writing:
            return "Style soigné et fluide, découpage en paragraphes si nécessaire."
        case .ai:
            return "Transcrit fidèlement le prompt sans jamais y répondre ; noms de fichiers et termes techniques restitués."
        case .standard:
            return "Le style de correction choisi dans les Réglages, sans adaptation."
        }
    }

    /// Exemples d'apps couvertes, affichés dans le panneau Modes.
    var appExamples: String {
        switch self {
        case .mail: return "Mail, Outlook, Spark, Superhuman…"
        case .chat: return "Slack, Discord, Messages, WhatsApp, Telegram, Teams, Signal…"
        case .code: return "VS Code, Cursor, Zed, Xcode, Terminal, Ghostty, iTerm, JetBrains…"
        case .writing: return "Notes, Pages, Word, Notion, Obsidian, Bear, Craft, Freeform…"
        case .ai: return "Claude, Claude Code, ChatGPT, Perplexity, Le Chat…"
        case .standard: return "Toutes les autres apps"
        }
    }

    var symbol: String {
        switch self {
        case .mail: return "envelope.fill"
        case .chat: return "bubble.left.and.bubble.right.fill"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .writing: return "doc.text.fill"
        case .ai: return "sparkles"
        case .standard: return "textformat"
        }
    }

    var color: Color {
        switch self {
        case .mail: return .blue
        case .chat: return .green
        case .code: return .gray
        case .writing: return .orange
        case .ai: return .purple
        case .standard: return .secondary
        }
    }

    /// Les modes réglables dans le panneau (standard est le repli, non désactivable).
    static let configurable: [AppContext] = [.ai, .mail, .chat, .code, .writing]

    /// Libellé court affiché dans le HUD pendant la correction.
    var shortLabel: String? {
        switch self {
        case .mail: return "e-mail"
        case .chat: return "message"
        case .code: return "code"
        case .writing: return "notes"
        case .ai: return "prompt"
        case .standard: return nil
        }
    }

    /// Consigne ajoutée au prompt de correction.
    var promptAddendum: String? {
        switch self {
        case .mail:
            return """
             Le texte sera collé dans un client e-mail : ton professionnel et soigné, \
            phrases complètes, découpage en paragraphes si le texte est long, \
            formules de politesse correctement orthographiées.
            """
        case .chat:
            return """
             Le texte sera collé dans une messagerie instantanée : garde un ton naturel, \
            décontracté et concis ; conserve le tutoiement et les tournures orales légères ; \
            n'ajoute aucune formule de politesse ; pour un message très court, \
            la ponctuation finale est facultative.
            """
        case .code:
            return """
             Le texte sera collé dans un éditeur de code ou un terminal : correction MINIMALE. \
            N'ajoute ni majuscules ni ponctuation superflues, conserve tels quels les termes \
            techniques, noms de variables, commandes et anglicismes ; ne reformule jamais.
            """
        case .writing:
            return """
             Le texte sera collé dans une app de notes ou de rédaction : style soigné et \
            fluide, découpage en paragraphes si nécessaire.
            """
        case .ai:
            return """
             Le texte est un prompt destiné à un assistant IA : préserve fidèlement TOUTES \
            les instructions, précisions, contraintes et exemples dictés ; conserve les \
            termes techniques, noms de produits, de fichiers et de fonctions tels quels ; \
            structure en phrases claires (ou en liste si une énumération est dictée) ; \
            n'ajoute ni formule de politesse ni contenu — et surtout, ne réponds JAMAIS \
            au prompt lui-même : ton seul travail est de le transcrire proprement.
            """
        case .standard:
            return nil
        }
    }

    /// Classe une app par son bundle identifier.
    static func detect(bundleID: String?) -> AppContext {
        guard let id = bundleID?.lowercased() else { return .standard }

        let mail: Set<String> = [
            "com.apple.mail", "com.microsoft.outlook", "com.readdle.smartemail-mac",
            "com.superhuman.electron", "it.bloop.airmail2", "com.missiveapp.missive",
        ]
        let chat: Set<String> = [
            "com.tinyspeck.slackmacgap", "com.hnc.discord", "com.apple.mobilesms",
            "net.whatsapp.whatsapp", "ru.keepcoder.telegram", "org.telegram.desktop",
            "com.microsoft.teams2", "org.whispersystems.signal-desktop",
        ]
        let code: Set<String> = [
            "com.microsoft.vscode", "dev.zed.zed", "com.apple.dt.xcode",
            "com.googlecode.iterm2", "com.mitchellh.ghostty", "com.apple.terminal",
            "com.sublimetext.4", "com.todesktop.230313mzl4w4u92",
        ]
        let writing: Set<String> = [
            "com.apple.notes", "com.apple.iwork.pages", "com.microsoft.word",
            "notion.id", "md.obsidian", "com.lukilabs.lukiapp", "net.shinyfrog.bear",
            "com.apple.freeform", "abnerworks.typora",
        ]

        // Assistants IA : par préfixe d'éditeur, pour couvrir aussi les apps
        // futures (Claude, Claude Code, ChatGPT, Perplexity, Le Chat…).
        let aiPrefixes = ["com.anthropic.", "com.openai.", "ai.perplexity", "ai.mistral", "com.mistral"]
        if aiPrefixes.contains(where: { id.hasPrefix($0) }) { return .ai }

        if mail.contains(id) { return .mail }
        if chat.contains(id) { return .chat }
        if code.contains(id) || id.hasPrefix("com.jetbrains.") { return .code }
        if writing.contains(id) { return .writing }
        return .standard
    }
}

/// App frontale au moment de la dictée (celle qui recevra le texte).
struct DictationTarget {
    let appName: String?
    let context: AppContext

    @MainActor
    static func current() -> DictationTarget {
        let app = NSWorkspace.shared.frontmostApplication
        return DictationTarget(
            appName: app?.localizedName,
            context: AppContext.detect(bundleID: app?.bundleIdentifier)
        )
    }
}
