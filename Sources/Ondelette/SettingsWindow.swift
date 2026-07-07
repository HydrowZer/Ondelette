import AppKit
import SwiftUI
import ServiceManagement

// MARK: - Fenêtre principale (sidebar façon app pro)

enum MainPane: String, CaseIterable, Identifiable {
    case home
    case history
    case modes
    case dictionary
    case settings

    var id: String { rawValue }

    var label: String {
        switch self {
        case .home: return "Accueil"
        case .history: return "Historique"
        case .modes: return "Modes"
        case .dictionary: return "Dictionnaire"
        case .settings: return "Réglages"
        }
    }

    var symbol: String {
        switch self {
        case .home: return "waveform"
        case .history: return "clock.arrow.circlepath"
        case .modes: return "wand.and.rays"
        case .dictionary: return "character.book.closed.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

@MainActor
final class MainNavModel: ObservableObject {
    @Published var pane: MainPane? = .home
}

@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let nav = MainNavModel()

    func show(pane: MainPane = .home) {
        if window == nil {
            let view = MainView(nav: nav)
            let hosting = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: hosting)
            window.title = "Ondelette"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.setContentSize(NSSize(width: 800, height: 560))
            window.minSize = NSSize(width: 680, height: 460)
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        nav.pane = pane
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct MainView: View {
    @ObservedObject var nav: MainNavModel

    var body: some View {
        NavigationSplitView {
            List(selection: $nav.pane) {
                Section {
                    ForEach(MainPane.allCases) { pane in
                        Label(pane.label, systemImage: pane.symbol)
                            .tag(pane)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack(spacing: 12) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 46, height: 46)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Ondelette")
                            .font(.system(size: 20, weight: .bold))
                        Text("Dictée vocale")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.leading, 16)
                .padding(.trailing, 12)
                .padding(.top, 26)
                .padding(.bottom, 14)
            }
            .safeAreaInset(edge: .bottom) {
                Text("Version 1.0 · 100 % local")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)
            }
        } detail: {
            switch nav.pane ?? .home {
            case .home: HomePane()
            case .history: HistoryPane()
            case .modes: ModesPane()
            case .dictionary: DictionaryPane()
            case .settings: SettingsPane()
            }
        }
        .frame(minWidth: 680, minHeight: 460)
    }
}

// MARK: - Accueil

struct HomePane: View {
    @ObservedObject private var history = HistoryStore.shared
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Prêt à dicter")
                        .font(.largeTitle.weight(.semibold))
                    Text("Maintiens \(settings.hotkey.label) et parle — le texte corrigé est collé dans l'app active.")
                        .foregroundStyle(.secondary)
                    if history.speedMultiplier >= 1.5 {
                        Text("Tu dictes \(history.speedMultiplier, specifier: "%.1f")× plus vite que tu ne tapes.")
                            .font(.callout.weight(.medium))
                            .foregroundStyle(Color.accentColor)
                            .padding(.top, 2)
                    }
                }

                HStack(spacing: 12) {
                    StatTile(value: "\(history.todayWords)", label: "mots aujourd'hui")
                    StatTile(value: "\(history.totalWords)", label: "mots au total")
                    StatTile(value: "\(history.totalCount)", label: "dictées")
                }

                HStack(spacing: 12) {
                    StatTile(
                        value: history.wordsPerMinute > 0 ? "\(history.wordsPerMinute)" : "—",
                        label: "mots / minute"
                    )
                    StatTile(value: Self.timeSavedText(history.timeSavedSeconds), label: "temps gagné")
                    StatTile(
                        value: history.streakDays > 0 ? "🔥 \(history.streakDays)" : "—",
                        label: history.streakDays > 1 ? "jours d'affilée" : "jour actif"
                    )
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Raccourcis")
                        .font(.headline)
                    ShortcutRow(symbol: "hand.tap.fill", text: "Maintenir \(settings.hotkey.label)", detail: "dicter (relâche pour coller)")
                    ShortcutRow(symbol: "lock.fill", text: "Double-appui", detail: "verrouiller la dictée longue, un appui pour finir")
                    ShortcutRow(symbol: "escape", text: "Échap", detail: "annuler l'enregistrement en cours")
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 12).fill(.quinary))

                Spacer(minLength: 0)
            }
            .padding(28)
            .frame(maxWidth: 560, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func timeSavedText(_ seconds: TimeInterval) -> String {
        guard seconds >= 60 else { return seconds > 0 ? "< 1 min" : "—" }
        let minutes = Int(seconds / 60)
        if minutes < 60 { return "\(minutes) min" }
        return "\(minutes / 60) h \(minutes % 60 > 0 ? "\(minutes % 60) min" : "")"
            .trimmingCharacters(in: .whitespaces)
    }
}

struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(.quinary))
    }
}

struct ShortcutRow: View {
    let symbol: String
    let text: String
    let detail: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .frame(width: 18)
                .foregroundStyle(.secondary)
            Text(text)
                .fontWeight(.medium)
            Text(detail)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .font(.system(size: 13))
    }
}

// MARK: - Historique

struct HistoryPane: View {
    @ObservedObject private var history = HistoryStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PaneHeader(title: "Historique") {
                if !history.entries.isEmpty {
                    Button("Tout effacer", role: .destructive) {
                        history.clear()
                    }
                }
            }
            if history.entries.isEmpty {
                ContentUnavailableView(
                    "Aucune dictée pour l'instant",
                    systemImage: "waveform",
                    description: Text("Tes dictées apparaîtront ici — pratique pour recopier un texte collé au mauvais endroit.")
                )
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(history.entries) { entry in
                        HistoryRow(entry: entry)
                    }
                }
                .listStyle(.inset)
            }
        }
    }
}

/// En-tête de panneau uniforme : même hauteur et même alignement partout.
struct PaneHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.largeTitle.weight(.semibold))
            Spacer()
            trailing
        }
        .padding(.horizontal, 28)
        .padding(.top, 28)
        .padding(.bottom, 12)
    }
}

extension PaneHeader where Trailing == EmptyView {
    init(title: String) {
        self.init(title: title) { EmptyView() }
    }
}

struct HistoryRow: View {
    let entry: DictationEntry
    @ObservedObject private var history = HistoryStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.final)
                .lineLimit(3)
            HStack {
                Text(entry.date.formatted(.relative(presentation: .named)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let app = entry.app {
                    Text("→ \(app)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(entry.final, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("Copier")
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button("Copier le texte corrigé") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(entry.final, forType: .string)
            }
            Button("Copier la transcription brute") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(entry.raw, forType: .string)
            }
            Divider()
            Button("Supprimer", role: .destructive) {
                history.remove(entry)
            }
        }
    }
}

// MARK: - Modes contextuels

struct ModesPane: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PaneHeader(title: "Modes")
            Form {
                Section {
                    Toggle(isOn: $settings.adaptToApp) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Adapter la correction à l'app active")
                                .fontWeight(.medium)
                            Text("Ondelette détecte l'app qui recevra le texte et ajuste le style. Le HUD affiche le mode utilisé (« Correction prompt… »).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Modes") {
                    ForEach(AppContext.configurable, id: \.self) { context in
                        ModeRow(context: context)
                            .disabled(!settings.adaptToApp)
                    }
                    ModeRow(context: .standard)
                        .disabled(true)
                }
            }
            .formStyle(.grouped)
        }
    }
}

struct ModeRow: View {
    let context: AppContext
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: context.symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(RoundedRectangle(cornerRadius: 6.5).fill(context.color.gradient))
            VStack(alignment: .leading, spacing: 2) {
                Text(context.displayName)
                    .fontWeight(.medium)
                Text(context.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(context.appExamples)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            if context != .standard {
                Toggle("", isOn: Binding(
                    get: { !settings.disabledContexts.contains(context.rawValue) },
                    set: { settings.setContext(context, enabled: $0) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Dictionnaire

struct DictionaryPane: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PaneHeader(title: "Dictionnaire")
            Form {
                Section {
                    VocabularyEditor()
                } footer: {
                    Text("Ces graphies exactes sont transmises à la correction : quand un mot dicté leur ressemble, c'est la forme du dictionnaire qui est écrite.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
        }
    }
}

// MARK: - Réglages

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var apiKey: String = KeychainHelper.loadAPIKey() ?? ""
    @Published var keySaved = false
    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled
    @Published var inputDevices: [AudioInputDevice] = AudioDevices.inputDevices()

    func refreshDevices() {
        inputDevices = AudioDevices.inputDevices()
    }

    func saveKey() {
        KeychainHelper.saveAPIKey(apiKey)
        keySaved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.keySaved = false
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

/// Icône de rangée façon Réglages Système : symbole blanc sur squircle coloré.
struct SettingsIcon: View {
    let symbol: String
    let color: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(RoundedRectangle(cornerRadius: 6.5).fill(color.gradient))
    }
}

struct SettingsPane: View {
    @ObservedObject private var settings = AppSettings.shared
    @StateObject private var model = SettingsViewModel()

    private let knownModels = ["gpt-5.4-mini", "gpt-5.5", "gpt-5.2", "gpt-5-mini"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PaneHeader(title: "Réglages")
            settingsForm
        }
        .onAppear { model.refreshDevices() }
    }

    private var settingsForm: some View {
        Form {
            Section("Correction GPT") {
                LabeledContent {
                    SecureField("sk-…", text: $model.apiKey)
                        .labelsHidden()
                        .frame(maxWidth: 220)
                        .onSubmit { model.saveKey() }
                } label: {
                    Label {
                        Text("Clé API OpenAI")
                    } icon: {
                        SettingsIcon(symbol: "key.fill", color: .gray)
                    }
                }
                HStack {
                    Spacer()
                    if model.keySaved {
                        Label("Enregistrée dans le Trousseau", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    Button("Enregistrer la clé") { model.saveKey() }
                        .buttonStyle(.glassProminent)
                }
                Picker(selection: $settings.gptModel) {
                    ForEach(knownModels, id: \.self) { Text($0) }
                    if !knownModels.contains(settings.gptModel) {
                        Text(settings.gptModel).tag(settings.gptModel)
                    }
                } label: {
                    Label {
                        Text("Modèle")
                    } icon: {
                        SettingsIcon(symbol: "sparkles", color: .purple)
                    }
                }
                Picker(selection: $settings.correctionStyle) {
                    ForEach(CorrectionStyle.allCases) { style in
                        Text(style.label).tag(style)
                    }
                } label: {
                    Label {
                        Text("Style de correction")
                    } icon: {
                        SettingsIcon(symbol: "wand.and.stars", color: .indigo)
                    }
                }
            }

            Section("Dictée") {
                Picker(selection: $settings.engine) {
                    ForEach(TranscriptionEngine.allCases) { engine in
                        Text(engine.label).tag(engine)
                    }
                } label: {
                    Label {
                        Text("Moteur local")
                    } icon: {
                        SettingsIcon(symbol: "waveform", color: .blue)
                    }
                }
                Picker(selection: $settings.micUID) {
                    Text("Automatique (évite les micros Bluetooth)").tag("")
                    ForEach(model.inputDevices) { device in
                        Text(device.name).tag(device.uid)
                    }
                    if !settings.micUID.isEmpty,
                       !model.inputDevices.contains(where: { $0.uid == settings.micUID }) {
                        Text("Micro débranché").tag(settings.micUID)
                    }
                } label: {
                    Label {
                        Text("Microphone")
                    } icon: {
                        SettingsIcon(symbol: "mic.fill", color: .orange)
                    }
                }
                Picker(selection: $settings.hotkey) {
                    ForEach(HotkeyChoice.allCases) { choice in
                        Text(choice.label).tag(choice)
                    }
                } label: {
                    Label {
                        Text("Touche à maintenir")
                    } icon: {
                        SettingsIcon(symbol: "keyboard", color: .cyan)
                    }
                }
                Picker(selection: $settings.languageCode) {
                    ForEach(AppSettings.languageOptions, id: \.code) { option in
                        Text(option.label).tag(option.code)
                    }
                } label: {
                    Label {
                        Text("Langue")
                    } icon: {
                        SettingsIcon(symbol: "globe", color: .green)
                    }
                }
                Toggle(isOn: $settings.muteWhileRecording) {
                    Label {
                        Text("Couper le son pendant la dictée")
                    } icon: {
                        SettingsIcon(symbol: "speaker.slash.fill", color: .pink)
                    }
                }
                Toggle(isOn: $settings.playSounds) {
                    Label {
                        Text("Sons de début/fin")
                    } icon: {
                        SettingsIcon(symbol: "bell.fill", color: .red)
                    }
                }
            }

            Section {
                Toggle(isOn: $model.launchAtLogin) {
                    Label {
                        Text("Lancer au démarrage de session")
                    } icon: {
                        SettingsIcon(symbol: "power", color: .secondary)
                    }
                }
                .onChange(of: model.launchAtLogin) { _, enabled in
                    model.setLaunchAtLogin(enabled)
                }
            } footer: {
                Text("La voix est transcrite sur cette machine — aucun audio n'est envoyé en ligne. Seul le texte transcrit passe par l'API OpenAI pour la correction.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Vocabulaire personnalisé (pastilles)

@MainActor
final class VocabularyFieldModel: ObservableObject {
    @Published var newTerm = ""
}

struct VocabularyEditor: View {
    @ObservedObject private var settings = AppSettings.shared
    @StateObject private var field = VocabularyFieldModel()

    private var terms: [String] { settings.vocabularyTerms }
    private var trimmed: String { field.newTerm.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                TextField("Prénom, marque, jargon… puis ⏎", text: $field.newTerm)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(add)
                Button(action: add) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(trimmed.isEmpty ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.accentColor))
                }
                .buttonStyle(.plain)
                .disabled(trimmed.isEmpty)
            }
            if terms.isEmpty {
                Text("Le micro écorche toujours le même mot ? Ajoute-le ici.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(terms, id: \.self) { term in
                        chip(term)
                    }
                }
                .animation(.snappy(duration: 0.2), value: terms)
            }
        }
        .padding(.vertical, 2)
    }

    private func add() {
        let term = trimmed
        guard !term.isEmpty else { return }
        guard !terms.contains(where: { $0.caseInsensitiveCompare(term) == .orderedSame }) else {
            field.newTerm = ""
            return
        }
        settings.customVocabulary = (terms + [term]).joined(separator: "\n")
        field.newTerm = ""
    }

    private func remove(_ term: String) {
        settings.customVocabulary = terms.filter { $0 != term }.joined(separator: "\n")
    }

    private func chip(_ term: String) -> some View {
        HStack(spacing: 5) {
            Text(term)
                .font(.system(size: 12, weight: .medium))
            Button {
                remove(term)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Supprimer « \(term) »")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.accentColor.opacity(0.15)))
        .overlay(Capsule().stroke(Color.accentColor.opacity(0.25), lineWidth: 0.5))
    }
}

/// Disposition en lignes qui passent à la ligne (pastilles de tags).
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 320
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(size)
            )
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
