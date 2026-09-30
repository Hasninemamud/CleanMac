import Foundation
import AVFoundation

enum PrivacyStatus {
    static func cameraInUse() -> Bool {
        AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    static func microphoneInUse() -> Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    static var summary: String {
        var parts: [String] = []
        if cameraInUse() { parts.append("Camera allowed") }
        if microphoneInUse() { parts.append("Mic allowed") }
        return parts.isEmpty ? "No camera/mic permission granted" : parts.joined(separator: " · ")
    }
}
