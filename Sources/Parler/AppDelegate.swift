import AppKit
import AVFoundation
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var statusMenuItem: NSMenuItem!

    private let hotkey = HotkeyManager()
    private let recorder = AudioRecorder()
    private let transcriber = Transcriber()
    private let hud = HUDController()
    private let settingsWindow = SettingsWindowController()
    private let muter = OutputMuter()

    /// Phases du cycle push-to-talk :
    /// holding = touche maintenue ; awaitingLock = relâchée très vite, on attend
    /// un éventuel second appui (double-appui = verrouillage) ; locked = dictée
    /// verrouillée, un appui l'arrête ; Échap annule à tout moment.
    private enum DictationPhase { case idle, holding, awaitingLock, locked }
    private var phase: DictationPhase = .idle
    private var lockWait: DispatchWorkItem?

    private var isBusy = false
    private var recordingStart: Date?
    private var readyEngines: Set<TranscriptionEngine> = []
    private var cancellables = Set<AnyCancellable>()

    private var modelReady: Bool {
        readyEngines.contains(AppSettings.shared.engine)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        requestPermissions()
        loadModel(engine: AppSettings.shared.engine)

        hotkey.onPress = { [weak self] in self?.hotkeyPressed() }
        hotkey.onRelease = { [weak self] in self?.hotkeyReleased() }
        hotkey.onEscape = { [weak self] in self?.cancelDictation() }
        hotkey.onActiveChange = { [weak self] active in
            guard let self else { return }
            if active {
                self.refreshReadyStatus()
            } else {
                self.updateStatus("⚠️ Accorde l'Accessibilité (menu ci-dessous)")
            }
        }
        hotkey.start()

        AppSettings.shared.$hotkey
            .sink { [weak self] choice in self?.hotkey.choice = choice }
            .store(in: &cancellables)

        AppSettings.shared.$engine
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] engine in self?.loadModel(engine: engine) }
            .store(in: &cancellables)

        recorder.onLevel = { [weak self] level in
            Task { @MainActor in self?.hud.setLevel(level) }
        }
    }

    // MARK: - Barre de menus

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setIcon(recording: false)

        let menu = NSMenu()
        statusMenuItem = NSMenuItem(title: "Démarrage…", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Ouvrir Parler", action: #selector(openMain), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "Historique", action: #selector(openHistory), keyEquivalent: "h"))
        menu.addItem(NSMenuItem(title: "Réglages…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Autorisations système…", action: #selector(openPrivacySettings), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quitter Parler", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func setIcon(recording: Bool) {
        statusItem.button?.image = MenuBarIcon.make(recording: recording)
        statusItem.button?.toolTip = "Parler"
    }

    private func updateStatus(_ text: String) {
        statusMenuItem.title = text
    }

    // MARK: - Autorisations & modèle

    private func requestPermissions() {
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    private func loadModel(engine: TranscriptionEngine) {
        guard !readyEngines.contains(engine) else {
            refreshReadyStatus()
            return
        }
        updateStatus("Préparation du modèle (première fois : plusieurs minutes)…")
        Task {
            do {
                try await transcriber.prepare(engine: engine)
                readyEngines.insert(engine)
                refreshReadyStatus()
            } catch {
                updateStatus("Erreur modèle : \(error.localizedDescription)")
                hud.show(.error("Échec du chargement du modèle"))
            }
        }
    }

    private func refreshReadyStatus() {
        if !hotkey.isActive {
            updateStatus("⚠️ Accorde l'Accessibilité (menu ci-dessous)")
        } else if !modelReady {
            updateStatus("Préparation du modèle (première fois : plusieurs minutes)…")
        } else {
            updateStatus("Prêt · maintiens \(AppSettings.shared.hotkey.shortLabel)")
        }
    }

    // MARK: - Cycle de dictée

    private func hotkeyPressed() {
        switch phase {
        case .locked:
            phase = .idle
            finishDictation()
        case .awaitingLock:
            lockWait?.cancel()
            lockWait = nil
            phase = .locked
            hud.show(.recordingLocked)
        case .holding:
            break
        case .idle:
            if startDictation() { phase = .holding }
        }
    }

    private func hotkeyReleased() {
        switch phase {
        case .holding:
            let duration = Date().timeIntervalSince(recordingStart ?? Date())
            if duration < 0.4 {
                // Peut-être la première moitié d'un double-appui : on attend un peu.
                phase = .awaitingLock
                let work = DispatchWorkItem { [weak self] in
                    guard let self, self.phase == .awaitingLock else { return }
                    self.cancelDictation()
                }
                lockWait = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
            } else {
                phase = .idle
                finishDictation()
            }
        case .locked, .awaitingLock:
            break
        case .idle:
            if case .loadingModel = hud.model.state { hud.hide() }
        }
    }

    private func startDictation() -> Bool {
        guard !isBusy else { return false }
        guard modelReady else {
            hud.show(.loadingModel)
            return false
        }
        do {
            try recorder.start()
            recordingStart = Date()
            hotkey.recordingActive = true
            setIcon(recording: true)
            hud.show(.recording)
            playSound(start: true)
            if AppSettings.shared.muteWhileRecording {
                muter.mute()
            }
            return true
        } catch {
            hud.show(.error(error.localizedDescription))
            return false
        }
    }

    private func cancelDictation() {
        lockWait?.cancel()
        lockWait = nil
        phase = .idle
        guard recorder.isRecording else { return }
        recorder.cancel()
        muter.restore()
        hotkey.recordingActive = false
        setIcon(recording: false)
        playSound(start: false)
        hud.hide()
    }

    private func finishDictation() {
        guard recorder.isRecording else {
            if case .loadingModel = hud.model.state { hud.hide() }
            return
        }
        let samples = recorder.stop()
        muter.restore()
        hotkey.recordingActive = false
        setIcon(recording: false)
        playSound(start: false)

        // Trop court pour contenir de la parole : on annule sans bruit.
        guard samples.count > 6000 else {
            hud.hide()
            return
        }

        isBusy = true
        hud.show(.transcribing)

        Task {
            defer { isBusy = false }
            do {
                let code = AppSettings.shared.languageCode
                let engine = AppSettings.shared.engine
                let transcriber = self.transcriber
                // Garde-fou : jamais de HUD bloqué indéfiniment sur « Transcription… ».
                let raw = try await withThrowingTaskGroup(of: String.self) { group in
                    group.addTask {
                        try await transcriber.transcribe(
                            samples,
                            engine: engine,
                            languageCode: code == "auto" ? nil : code
                        )
                    }
                    group.addTask {
                        try await Task.sleep(nanoseconds: 120_000_000_000)
                        throw NSError(domain: "Parler", code: 10, userInfo: [
                            NSLocalizedDescriptionKey: "Transcription trop longue (2 min) — réessaie."
                        ])
                    }
                    let result = try await group.next()!
                    group.cancelAll()
                    return result
                }
                guard !raw.isEmpty else {
                    hud.show(.error("Rien entendu"))
                    return
                }

                let style = AppSettings.shared.correctionStyle
                var final = raw
                if style != .off {
                    hud.show(.correcting)
                    let targetLanguage = AppSettings.languageOptions
                        .first { $0.code == code && code != "auto" }?.label
                    do {
                        final = try await Corrector.correct(
                            raw,
                            style: style,
                            model: AppSettings.shared.gptModel,
                            targetLanguage: targetLanguage
                        )
                    } catch {
                        // La dictée ne doit jamais être perdue : on colle le brut.
                        NSLog("Correction échouée : \(error.localizedDescription)")
                        hud.show(.error("Correction échouée — texte brut collé"))
                        Paster.paste(raw)
                        HistoryStore.shared.add(raw: raw, final: raw)
                        return
                    }
                }

                Paster.paste(final)
                HistoryStore.shared.add(raw: raw, final: final)
                hud.show(.done)
            } catch {
                hud.show(.error(error.localizedDescription))
            }
        }
    }

    private func playSound(start: Bool) {
        guard AppSettings.shared.playSounds else { return }
        NSSound(named: start ? "Tink" : "Pop")?.play()
    }

    // MARK: - Actions du menu

    @objc private func openMain() {
        settingsWindow.show(pane: .home)
    }

    @objc private func openHistory() {
        settingsWindow.show(pane: .history)
    }

    @objc private func openSettings() {
        settingsWindow.show(pane: .settings)
    }

    @objc private func openPrivacySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
