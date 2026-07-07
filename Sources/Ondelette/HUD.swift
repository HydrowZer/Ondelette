import AppKit
import SwiftUI

enum HUDState: Equatable {
    case hidden
    case loadingModel
    case recording
    case recordingLocked
    case transcribing
    /// Correction en cours, avec le contexte détecté (« e-mail », « code »…).
    case correcting(String?)
    case done
    case error(String)
}

@MainActor
final class HUDModel: ObservableObject {
    @Published var state: HUDState = .hidden
    @Published var level: Float = 0
    /// Fenêtre glissante des derniers niveaux : dessine une forme d'onde vivante.
    @Published var levels: [Float] = Array(repeating: 0, count: 16)

    func pushLevel(_ value: Float) {
        level = value
        levels.removeFirst()
        levels.append(value)
    }

    func resetLevels() {
        levels = Array(repeating: 0, count: 16)
        level = 0
    }
}

@MainActor
final class HUDController {
    private let panel: NSPanel
    let model = HUDModel()
    private var hideTask: Task<Void, Never>?

    init() {
        let size = NSSize(width: 340, height: 56)
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: HUDView(model: model))
    }

    func show(_ state: HUDState) {
        hideTask?.cancel()
        model.state = state
        position()
        panel.orderFrontRegardless()

        switch state {
        case .done:
            scheduleHide(after: 0.9)
        case .error:
            scheduleHide(after: 3.5)
        default:
            break
        }
    }

    func setLevel(_ level: Float) {
        model.pushLevel(level)
    }

    func hide() {
        hideTask?.cancel()
        model.state = .hidden
        model.resetLevels()
        panel.orderOut(nil)
    }

    private func scheduleHide(after seconds: Double) {
        hideTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.hide()
        }
    }

    private func position() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let size = panel.frame.size
        let origin = NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.minY + 36
        )
        panel.setFrameOrigin(origin)
    }
}

struct HUDView: View {
    @ObservedObject var model: HUDModel

    private var isRecording: Bool {
        model.state == .recording || model.state == .recordingLocked
    }

    var body: some View {
        HStack(spacing: 10) {
            if isRecording {
                // Pilule waveform façon Wispr Flow : l'onde EST le message.
                if model.state == .recordingLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                Waveform(levels: model.levels)
            } else {
                icon
                    .frame(width: 16)
                Text(text)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, isRecording ? 16 : 18)
        .padding(.vertical, 11)
        .frame(minWidth: isRecording ? 96 : 0, minHeight: 38)
        .glassEffect(.regular.tint(.black.opacity(0.45)), in: .capsule)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(model.state == .hidden ? 0 : 1)
        .animation(.easeOut(duration: 0.18), value: model.state)
    }

    @ViewBuilder
    private var icon: some View {
        switch model.state {
        case .recording, .recordingLocked:
            EmptyView()
        case .transcribing, .correcting, .loadingModel:
            ProgressView()
                .controlSize(.small)
                .tint(.white)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, options: .nonRepeating)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13))
                .foregroundStyle(.yellow)
        case .hidden:
            EmptyView()
        }
    }

    private var text: String {
        switch model.state {
        case .hidden: return ""
        case .loadingModel: return "Chargement du modèle…"
        case .recording: return "Je t'écoute…"
        case .recordingLocked: return "Dictée verrouillée — appuie pour finir"
        case .transcribing: return "Transcription…"
        case .correcting(let context):
            return context.map { "Correction \($0)…" } ?? "Correction…"
        case .done: return "Collé ✓"
        case .error(let message): return message
        }
    }
}

/// Forme d'onde vivante : chaque barre est un niveau récent, l'onde défile.
struct Waveform: View {
    var levels: [Float]

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(levels.indices, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.25)
                    .fill(.white.opacity(0.92))
                    .frame(width: 2.5, height: 3 + CGFloat(levels[i]) * 17)
            }
        }
        .animation(.linear(duration: 0.07), value: levels)
    }
}
