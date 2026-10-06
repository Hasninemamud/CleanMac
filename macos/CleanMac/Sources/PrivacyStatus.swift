import Foundation
import AVFoundation

enum PrivacyStatus {
    /// Permission state for CleanMac itself (not live device capture by other apps).
    static func cameraAllowed() -> Bool {
        AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    static func microphoneAllowed() -> Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    static var summary: String {
        var parts: [String] = []
        if cameraAllowed() { parts.append("Camera OK") }
        if microphoneAllowed() { parts.append("Mic OK") }
        return parts.isEmpty ? "Camera/Mic access off" : parts.joined(separator: " · ")
    }
}
