import CoreAudio
import Foundation

/// Coupe le son de sortie pendant la dictée (la musique ne « bave » pas dans le
/// micro) et restaure l'état exact d'avant à la fin. Utilise la propriété mute
/// du périphérique de sortie, avec repli sur le volume si mute n'existe pas.
final class OutputMuter {
    private var deviceID: AudioDeviceID?
    private var savedMute: UInt32?
    private var savedVolume: Float32?

    func mute() {
        guard savedMute == nil, savedVolume == nil else { return }
        guard let device = Self.defaultOutputDevice() else { return }
        deviceID = device

        var muteAddress = Self.address(kAudioDevicePropertyMute)
        if AudioObjectHasProperty(device, &muteAddress), Self.isSettable(device, &muteAddress) {
            var current: UInt32 = 0
            var size = UInt32(MemoryLayout<UInt32>.size)
            guard AudioObjectGetPropertyData(device, &muteAddress, 0, nil, &size, &current) == noErr
            else { return }
            savedMute = current
            var muted: UInt32 = 1
            AudioObjectSetPropertyData(device, &muteAddress, 0, nil, size, &muted)
            return
        }

        var volumeAddress = Self.address(kAudioDevicePropertyVolumeScalar)
        if AudioObjectHasProperty(device, &volumeAddress), Self.isSettable(device, &volumeAddress) {
            var current: Float32 = 0
            var size = UInt32(MemoryLayout<Float32>.size)
            guard AudioObjectGetPropertyData(device, &volumeAddress, 0, nil, &size, &current) == noErr
            else { return }
            savedVolume = current
            var zero: Float32 = 0
            AudioObjectSetPropertyData(device, &volumeAddress, 0, nil, size, &zero)
        }
    }

    func restore() {
        guard let device = deviceID else { return }
        if var mute = savedMute {
            var muteAddress = Self.address(kAudioDevicePropertyMute)
            AudioObjectSetPropertyData(
                device, &muteAddress, 0, nil, UInt32(MemoryLayout<UInt32>.size), &mute)
        }
        if var volume = savedVolume {
            var volumeAddress = Self.address(kAudioDevicePropertyVolumeScalar)
            AudioObjectSetPropertyData(
                device, &volumeAddress, 0, nil, UInt32(MemoryLayout<Float32>.size), &volume)
        }
        savedMute = nil
        savedVolume = nil
        deviceID = nil
    }

    private static func address(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private static func isSettable(
        _ device: AudioDeviceID,
        _ address: inout AudioObjectPropertyAddress
    ) -> Bool {
        var settable = DarwinBoolean(false)
        return AudioObjectIsPropertySettable(device, &address, &settable) == noErr
            && settable.boolValue
    }

    private static func defaultOutputDevice() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device)
        guard status == noErr, device != 0 else { return nil }
        return device
    }
}
