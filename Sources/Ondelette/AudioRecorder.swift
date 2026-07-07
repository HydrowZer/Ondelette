import AVFoundation
import CoreMedia
import Foundation

/// Capture le micro via AVCaptureSession (sélection de périphérique fiable,
/// contrairement à AVAudioEngine) et accumule des échantillons Float32 mono
/// 16 kHz (format attendu par Whisper et Parakeet).
final class AudioRecorder: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate {
    private var session: AVCaptureSession?
    private let captureQueue = DispatchQueue(label: "com.charles.ondelette.audio")
    private var converter: AVAudioConverter?
    private var lastInputFormat: AVAudioFormat?
    private let outFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 16000,
        channels: 1,
        interleaved: false
    )!
    private var samples: [Float] = []
    private let lock = NSLock()

    /// Niveau RMS (0…1 environ) pour l'animation du HUD. Appelé hors main thread.
    var onLevel: ((Float) -> Void)?

    private(set) var isRecording = false

    func start() throws {
        guard !isRecording else { return }
        lock.lock()
        samples.removeAll(keepingCapacity: true)
        lock.unlock()
        converter = nil
        lastInputFormat = nil

        guard let device = resolveDevice() else {
            throw NSError(domain: "Ondelette", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Aucun micro disponible."
            ])
        }
        NSLog("Ondelette audio: capture sur « %@ »", device.localizedName)

        let session = AVCaptureSession()
        session.beginConfiguration()
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            throw NSError(domain: "Ondelette", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Micro « \(device.localizedName) » indisponible."
            ])
        }
        session.addInput(input)
        let output = AVCaptureAudioDataOutput()
        output.setSampleBufferDelegate(self, queue: captureQueue)
        guard session.canAddOutput(output) else {
            throw NSError(domain: "Ondelette", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "Sortie audio indisponible."
            ])
        }
        session.addOutput(output)
        session.commitConfiguration()
        session.startRunning()

        self.session = session
        isRecording = true
    }

    /// Arrête la capture et renvoie tous les échantillons accumulés.
    func stop() -> [Float] {
        guard isRecording else { return [] }
        session?.stopRunning()
        session = nil
        isRecording = false
        lock.lock()
        defer { lock.unlock() }
        return samples
    }

    func cancel() {
        _ = stop()
        lock.lock()
        samples.removeAll()
        lock.unlock()
    }

    /// Micro à utiliser :
    /// - UID choisi dans les réglages s'il est branché ;
    /// - sinon micro système, sauf s'il est Bluetooth (ouvrir son micro forcerait
    ///   le profil « appel » et dégraderait le son des écouteurs) → micro intégré.
    private func resolveDevice() -> AVCaptureDevice? {
        let uid = AppSettings.shared.micUID
        if !uid.isEmpty, let chosen = AVCaptureDevice(uniqueID: uid) {
            return chosen
        }
        let systemDefault = AVCaptureDevice.default(for: .audio)
        if let systemDefault,
           let coreAudioID = AudioDevices.device(withUID: systemDefault.uniqueID)?.id,
           AudioDevices.isBluetooth(coreAudioID),
           let builtIn = AudioDevices.builtInInputDevice(),
           let builtInCapture = AVCaptureDevice(uniqueID: builtIn.uid) {
            NSLog("Ondelette audio: micro système Bluetooth évité au profit du micro intégré")
            return builtInCapture
        }
        return systemDefault
    }

    // MARK: - AVCaptureAudioDataOutputSampleBufferDelegate

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard
            let description = CMSampleBufferGetFormatDescription(sampleBuffer),
            let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(description),
            let inFormat = AVAudioFormat(streamDescription: asbd)
        else { return }

        let frames = AVAudioFrameCount(CMSampleBufferGetNumSamples(sampleBuffer))
        guard frames > 0, let pcm = AVAudioPCMBuffer(pcmFormat: inFormat, frameCapacity: frames) else {
            return
        }
        pcm.frameLength = frames
        let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(
            sampleBuffer, at: 0, frameCount: Int32(frames), into: pcm.mutableAudioBufferList)
        guard status == noErr else { return }

        if converter == nil || lastInputFormat != inFormat {
            converter = AVAudioConverter(from: inFormat, to: outFormat)
            lastInputFormat = inFormat
        }
        guard let converter else { return }

        let ratio = outFormat.sampleRate / inFormat.sampleRate
        let capacity = AVAudioFrameCount(Double(frames) * ratio) + 16
        guard let out = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: capacity) else { return }

        var consumed = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, statusPointer in
            if consumed {
                statusPointer.pointee = .noDataNow
                return nil
            }
            consumed = true
            statusPointer.pointee = .haveData
            return pcm
        }
        guard error == nil, let channel = out.floatChannelData?[0] else { return }

        let count = Int(out.frameLength)
        guard count > 0 else { return }

        lock.lock()
        samples.append(contentsOf: UnsafeBufferPointer(start: channel, count: count))
        lock.unlock()

        var sum: Float = 0
        for i in 0..<count { sum += channel[i] * channel[i] }
        // Échelle perceptuelle : même un chuchotement fait bouger les barres.
        let rms = sqrt(sum / Float(count))
        onLevel?(min(1, pow(rms, 0.4) * 1.8))
    }
}
