import SwiftUI
import SceneKit

/// Rotating Mole-style globe for the Clean hero.
struct EarthGlobeView: NSViewRepresentable {
    var spinningFast: Bool = false

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = Self.makeScene()
        view.backgroundColor = .clear
        view.allowsCameraControl = false
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling4X
        view.isPlaying = true
        view.loops = true
        context.coordinator.fast = spinningFast
        context.coordinator.restart(spinningFast, in: view)
        return view
    }

    func updateNSView(_ view: SCNView, context: Context) {
        guard context.coordinator.fast != spinningFast else { return }
        context.coordinator.fast = spinningFast
        context.coordinator.restart(spinningFast, in: view)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var fast = false

        func restart(_ fast: Bool, in view: SCNView) {
            guard let earth = view.scene?.rootNode.childNode(withName: "earth", recursively: true) else { return }
            earth.removeAllActions()
            let duration: TimeInterval = fast ? 8 : 28
            earth.runAction(.repeatForever(.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: duration)))
        }
    }

    private static func makeScene() -> SCNScene {
        let scene = SCNScene()

        let sphere = SCNSphere(radius: 1.0)
        sphere.segmentCount = 64
        let earth = SCNNode(geometry: sphere)
        earth.name = "earth"
        let mat = SCNMaterial()
        mat.diffuse.contents = earthTexture()
        mat.emission.contents = NSColor(calibratedRed: 0.05, green: 0.12, blue: 0.28, alpha: 1)
        mat.emission.intensity = 0.35
        mat.specular.contents = NSColor.white.withAlphaComponent(0.35)
        mat.shininess = 0.25
        mat.locksAmbientWithDiffuse = true
        earth.geometry?.firstMaterial = mat
        earth.eulerAngles = SCNVector3(-0.35, 0.6, 0.08)
        scene.rootNode.addChildNode(earth)

        let atmosphere = SCNNode(geometry: SCNSphere(radius: 1.045))
        let atm = SCNMaterial()
        atm.diffuse.contents = NSColor.clear
        atm.emission.contents = NSColor(calibratedRed: 0.35, green: 0.55, blue: 0.95, alpha: 1)
        atm.emission.intensity = 0.2
        atm.transparency = 0.72
        atm.writesToDepthBuffer = false
        atmosphere.geometry?.firstMaterial = atm
        scene.rootNode.addChildNode(atmosphere)

        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.intensity = 900
        key.light?.color = NSColor(calibratedRed: 1, green: 0.98, blue: 0.92, alpha: 1)
        key.eulerAngles = SCNVector3(-0.6, 0.8, 0)
        scene.rootNode.addChildNode(key)

        let fill = SCNNode()
        fill.light = SCNLight()
        fill.light?.type = .ambient
        fill.light?.intensity = 280
        fill.light?.color = NSColor(calibratedRed: 0.45, green: 0.55, blue: 0.75, alpha: 1)
        scene.rootNode.addChildNode(fill)

        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.fieldOfView = 32
        camera.position = SCNVector3(0, 0.15, 3.6)
        scene.rootNode.addChildNode(camera)
        return scene
    }

    /// Procedural blue-marble-ish texture — no bundled asset required.
    private static func earthTexture() -> NSImage {
        let size = 512
        let img = NSImage(size: NSSize(width: size, height: size))
        img.lockFocus()
        NSColor(calibratedRed: 0.12, green: 0.28, blue: 0.55, alpha: 1).setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()

        let land = NSColor(calibratedRed: 0.28, green: 0.55, blue: 0.32, alpha: 1)
        let cloud = NSColor.white.withAlphaComponent(0.18)
        var rng = SeededRNG(seed: 42)
        for _ in 0..<90 {
            let w = CGFloat(rng.next(in: 40...120))
            let h = CGFloat(rng.next(in: 20...70))
            let x = CGFloat(rng.next(in: 0...size))
            let y = CGFloat(rng.next(in: 0...size))
            land.setFill()
            NSBezierPath(ovalIn: NSRect(x: x, y: y, width: w, height: h)).fill()
        }
        for _ in 0..<50 {
            let w = CGFloat(rng.next(in: 30...100))
            let h = CGFloat(rng.next(in: 10...40))
            let x = CGFloat(rng.next(in: 0...size))
            let y = CGFloat(rng.next(in: 0...size))
            cloud.setFill()
            NSBezierPath(ovalIn: NSRect(x: x, y: y, width: w, height: h)).fill()
        }
        img.unlockFocus()
        return img
    }
}

private struct SeededRNG {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 1 : seed }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
    mutating func next(in range: ClosedRange<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next() % span)
    }
}
