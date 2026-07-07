import Accelerate
import Foundation
import FluidAudio
import WhisperKit

enum TranscriberError: LocalizedError {
    case notReady

    var errorDescription: String? {
        switch self {
        case .notReady: return "Le modèle de transcription n'est pas encore chargé."
        }
    }
}

/// Transcription 100 % locale, avec deux moteurs au choix :
/// - Whisper large-v3 turbo (WhisperKit, CoreML) : précision maximale, langue forcée.
/// - Parakeet V3 (FluidAudio, CoreML) : ultra rapide, langue auto-détectée.
actor Transcriber {
    private var parakeet: AsrManager?
    private var whisper: WhisperKit?
    private var loading = false

    /// Télécharge (premier usage) puis charge le moteur demandé.
    /// Les moteurs déjà chargés restent en mémoire pour basculer sans attente.
    func prepare(engine: TranscriptionEngine) async throws {
        guard !loading else { return }
        loading = true
        defer { loading = false }

        switch engine {
        case .whisper:
            guard whisper == nil else { return }
            let config = WhisperKitConfig(model: "large-v3-v20240930_turbo")
            let pipe = try await WhisperKit(config)
            // Échauffement : la première inférence déclenche la spécialisation
            // du modèle pour l'ANE (plusieurs minutes la toute première fois,
            // mise en cache ensuite). On la fait ici, pas pendant une dictée.
            _ = try await pipe.transcribe(
                audioArray: [Float](repeating: 0, count: 16000),
                decodeOptions: DecodingOptions(task: .transcribe, language: "fr")
            )
            whisper = pipe
        case .parakeet:
            guard parakeet == nil else { return }
            let models = try await AsrModels.downloadAndLoad(version: .v3)
            let manager = AsrManager(config: .default)
            try await manager.loadModels(models)
            parakeet = manager
        }
    }

    func isReady(engine: TranscriptionEngine) -> Bool {
        switch engine {
        case .whisper: return whisper != nil
        case .parakeet: return parakeet != nil
        }
    }

    /// Transcrit des échantillons Float32 mono 16 kHz.
    /// `languageCode` : code ISO ("fr", "en", …) ou nil pour la détection automatique.
    /// Whisper force réellement la langue ; Parakeet ne peut que filtrer par alphabet.
    /// Normalise le gain : un chuchotement est 10-30× plus faible qu'une voix
    /// normale et ressort quasi muet du micro — on ramène le pic vers un niveau
    /// nominal avant de donner l'audio au modèle. Gain plafonné pour ne pas
    /// transformer du silence pur en bruit amplifié.
    private func normalized(_ samples: [Float]) -> [Float] {
        var peak: Float = 0
        vDSP_maxmgv(samples, 1, &peak, vDSP_Length(samples.count))
        guard peak > 0.001, peak < 0.5 else { return samples }
        var gain = min(0.85 / peak, 30)
        var result = [Float](repeating: 0, count: samples.count)
        vDSP_vsmul(samples, 1, &gain, &result, 1, vDSP_Length(samples.count))
        return result
    }

    func transcribe(
        _ rawSamples: [Float],
        engine: TranscriptionEngine,
        languageCode: String?
    ) async throws -> String {
        let samples = normalized(rawSamples)
        switch engine {
        case .whisper:
            guard let whisper else { throw TranscriberError.notReady }
            let options = DecodingOptions(
                task: .transcribe,
                language: languageCode,
                temperature: 0,
                skipSpecialTokens: true
            )
            let results = try await whisper.transcribe(audioArray: samples, decodeOptions: options)
            let text = results.map(\.text).joined(separator: " ")
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        case .parakeet:
            guard let parakeet else { throw TranscriberError.notReady }
            let language = languageCode.flatMap { Language(rawValue: $0) }
            var decoderState = TdtDecoderState.make()
            let result = try await parakeet.transcribe(
                samples, decoderState: &decoderState, language: language)
            return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}
