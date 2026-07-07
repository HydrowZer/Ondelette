import AppKit
import CoreGraphics

/// Écoute globale de la touche push-to-talk (modificateur maintenu) via CGEventTap.
/// Nécessite l'autorisation Accessibilité. Tant qu'elle n'est pas accordée,
/// `start()` réessaie automatiquement toutes les 3 secondes.
final class HotkeyManager {
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?
    /// Échap pendant un enregistrement : annulation.
    var onEscape: (() -> Void)?
    /// Appelé quand l'état de l'écoute change (true = tap actif).
    var onActiveChange: ((Bool) -> Void)?

    var choice: HotkeyChoice = AppSettings.shared.hotkey
    /// Mis à jour par l'app : Échap n'est intercepté que pendant un enregistrement.
    var recordingActive = false

    private(set) var isActive = false

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var pressed = false
    private var retryTimer: Timer?

    func start() {
        guard tap == nil else { return }
        if createTap() {
            setActive(true)
        } else {
            setActive(false)
            scheduleRetry()
        }
    }

    private func scheduleRetry() {
        guard retryTimer == nil else { return }
        retryTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.createTap() {
                self.retryTimer?.invalidate()
                self.retryTimer = nil
                self.setActive(true)
            }
        }
    }

    private func createTap() -> Bool {
        guard AXIsProcessTrusted() else { return false }
        let mask = CGEventMask(
            (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue))
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
            let consume = manager.handle(type: type, event: event)
            return consume ? nil : Unmanaged.passUnretained(event)
        }
        // .defaultTap (actif) : couvert par l'autorisation Accessibilité,
        // contrairement à .listenOnly qui exige « Surveillance de l'entrée ».
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stopTap() {
        retryTimer?.invalidate()
        retryTimer = nil
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        tap = nil
        runLoopSource = nil
        setActive(false)
    }

    private func setActive(_ active: Bool) {
        isActive = active
        DispatchQueue.main.async { self.onActiveChange?(active) }
    }

    /// Renvoie true si l'événement doit être consommé (non transmis aux apps).
    private func handle(type: CGEventType, event: CGEvent) -> Bool {
        // macOS désactive le tap s'il est trop lent : on le réactive.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        }
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        // Échap pendant un enregistrement : annule la dictée et absorbe la touche
        // pour ne pas fermer un dialogue de l'app active par accident.
        if type == .keyDown {
            if keyCode == 53, recordingActive {
                DispatchQueue.main.async { self.onEscape?() }
                return true
            }
            return false
        }

        guard type == .flagsChanged, keyCode == choice.keyCode else { return false }

        let isDown = event.flags.contains(choice.flagMask)
        if isDown && !pressed {
            pressed = true
            DispatchQueue.main.async { self.onPress?() }
        } else if !isDown && pressed {
            pressed = false
            DispatchQueue.main.async { self.onRelease?() }
        }
        return false
    }
}
