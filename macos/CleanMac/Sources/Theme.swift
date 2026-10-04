import SwiftUI
import AppKit

enum Theme {
    // Mole carbon base (dark navy chrome — overridden per-page by Feature.pageBG).
    static let bg = Color(red: 0.118, green: 0.149, blue: 0.235)       // #1E263C Earth default
    static let rail = Color(red: 0.094, green: 0.118, blue: 0.188)      // #181E30
    static let surface = Color(red: 0.157, green: 0.188, blue: 0.275)   // #283046
    static let surface2 = Color(red: 0.196, green: 0.227, blue: 0.314)  // #323A50
    static let ink = Color.white
    static let muted = Color.white.opacity(0.55)
    static let line = Color.white.opacity(0.12)
    static let accent = Color(red: 0.357, green: 0.557, blue: 0.937)    // Earth link blue
    static let accentSoft = Color(red: 0.357, green: 0.557, blue: 0.937).opacity(0.18)
    static let ok = Color(red: 0.72, green: 0.83, blue: 0.36)           // Status lime
    static let warn = Color(red: 0.96, green: 0.62, blue: 0.22)
    static let danger = Color(red: 1.0, green: 0.478, blue: 0.361)      // Mars salmon

    /// Shared Mole chrome tokens (white CTA, blue link).
    enum Mole {
        static let bg = Color(red: 0.118, green: 0.149, blue: 0.235)
        static let rail = Color(red: 0.094, green: 0.118, blue: 0.188)
        static let surface = Color(red: 0.157, green: 0.188, blue: 0.275)
        static let surface2 = Color(red: 0.196, green: 0.227, blue: 0.314)
        static let ink = Color.white
        static let muted = Color.white.opacity(0.55)
        static let line = Color.white.opacity(0.12)
        static let link = Color(red: 0.45, green: 0.62, blue: 1.0)
        static let cta = Color.white
        static let ctaInk = Color(red: 0.110, green: 0.145, blue: 0.231)
    }

    /// Planet pages from mole.fit (Earth / Mars / Mercury / Jupiter / Sun).
    enum Feature {
        static let clean = Color(red: 0.357, green: 0.557, blue: 0.937)     // Earth blue
        static let apps = Color(red: 1.0, green: 0.478, blue: 0.361)        // Mars salmon #FF7A5C
        static let analyze = Color(red: 0.769, green: 0.643, blue: 0.518)   // Jupiter tan
        static let optimize = Color(red: 0.784, green: 0.769, blue: 0.745)  // Mercury grey
        static let status = Color(red: 0.722, green: 0.831, blue: 0.361)    // Sun lime

        static func accent(for section: AppState.NavSection) -> Color {
            switch section {
            case .clean: return clean
            case .software: return apps
            case .analyze: return analyze
            case .optimize: return optimize
            case .status: return status
            }
        }

        static func pageBG(for section: AppState.NavSection) -> Color {
            switch section {
            case .clean: return Color(red: 0.118, green: 0.149, blue: 0.235)    // #1E263C
            case .software: return Color(red: 0.102, green: 0.078, blue: 0.071)  // #1A1412 Mars
            case .analyze: return Color(red: 0.239, green: 0.169, blue: 0.122)   // #3D2B1F Jupiter
            case .optimize: return Color(red: 0.153, green: 0.145, blue: 0.149)  // #272526 Mercury
            case .status: return Color(red: 0.165, green: 0.157, blue: 0.122)    // #2A281F Sun
            }
        }

        static func rail(for section: AppState.NavSection) -> Color {
            switch section {
            case .clean: return Color(red: 0.094, green: 0.118, blue: 0.188)
            case .software: return Color(red: 0.082, green: 0.059, blue: 0.055)
            case .analyze: return Color(red: 0.196, green: 0.133, blue: 0.094)
            case .optimize: return Color(red: 0.118, green: 0.110, blue: 0.114)
            case .status: return Color(red: 0.133, green: 0.125, blue: 0.094)
            }
        }

        static func surface(for section: AppState.NavSection) -> Color {
            switch section {
            case .clean: return Color(red: 0.145, green: 0.184, blue: 0.275)
            case .software: return Color(red: 0.145, green: 0.110, blue: 0.106)  // #251C1B
            case .analyze: return Color(red: 0.290, green: 0.216, blue: 0.165)   // #4A372A
            case .optimize: return Color(red: 0.196, green: 0.188, blue: 0.184)  // #32302F
            case .status: return Color(red: 0.216, green: 0.204, blue: 0.161)    // #373429
            }
        }

        static func surface2(for section: AppState.NavSection) -> Color {
            switch section {
            case .clean: return Color(red: 0.180, green: 0.220, blue: 0.320)
            case .software: return Color(red: 0.192, green: 0.145, blue: 0.137)  // #312523
            case .analyze: return Color(red: 0.349, green: 0.263, blue: 0.200)   // #594333
            case .optimize: return Color(red: 0.255, green: 0.243, blue: 0.235)  // #413E3C
            case .status: return Color(red: 0.275, green: 0.259, blue: 0.204)    // #464234
            }
        }

        /// All Mole pages are dark planet chrome.
        static func isDark(_ section: AppState.NavSection) -> Bool { true }

        /// CTA label ink — dark charcoal on white pills (matches mole.fit).
        static var ctaInk: Color { Mole.ctaInk }
    }
}

/// Soft enter animation for page roots.
struct PageEnterModifier: ViewModifier {
    @State private var ready = false
    func body(content: Content) -> some View {
        content
            .opacity(ready ? 1 : 0)
            .offset(y: ready ? 0 : 16)
            .scaleEffect(ready ? 1 : 0.985)
            .onAppear {
                withAnimation(.spring(response: 0.48, dampingFraction: 0.86)) { ready = true }
            }
    }
}

extension View {
    func pageEnter() -> some View { modifier(PageEnterModifier()) }
}

struct BrandLogo: View {
    var size: CGFloat = 28

    var body: some View {
        Group {
            if let img = bundleLogo {
                Image(nsImage: img)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
            } else {
                Circle()
                    .fill(Color.white)
                    .overlay {
                        Text("C")
                            .font(.system(size: size * 0.42, weight: .bold))
                            .foregroundColor(Theme.Mole.ctaInk)
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var bundleLogo: NSImage? {
        if let url = Bundle.module.url(forResource: "logo", withExtension: "png") {
            return NSImage(contentsOf: url)
        }
        if let url = Bundle.main.url(forResource: "logo", withExtension: "png") {
            return NSImage(contentsOf: url)
        }
        return nil
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var disabled = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(Theme.Mole.ctaInk)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.white.opacity(disabled ? 0.4 : (configuration.isPressed ? 0.85 : 1)))
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

struct SoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(Theme.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Theme.surface)
            .overlay(
                Capsule().stroke(Theme.line, lineWidth: 1)
            )
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
            .fixedSize()
    }
}

struct DangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Theme.danger.opacity(configuration.isPressed ? 0.85 : 1))
            .clipShape(Capsule())
            .fixedSize()
    }
}

struct SegmentPill: View {
    let title: String
    let selected: Bool
    var dark = true
    var accent: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(selected
                    ? Theme.Mole.ctaInk
                    : Theme.Mole.muted)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                // Mole: selected tab is always a white pill.
                .background(selected ? Theme.Mole.cta : Color.clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct SafetyBadge: View {
    let safety: String

    var body: some View {
        Text(safety.uppercased())
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.2))
            .clipShape(Capsule())
            .fixedSize()
    }

    private var color: Color {
        switch safety {
        case "safe": return Theme.ok
        case "blocked": return Theme.danger
        default: return Theme.warn
        }
    }
}

struct CheckMark: View {
    @Binding var isOn: Bool
    var disabled = false
    var accent: Color = Theme.accent

    var body: some View {
        Button {
            if !disabled { isOn.toggle() }
        } label: {
            Image(systemName: isOn ? "checkmark.square.fill" : "square")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(disabled ? Theme.muted.opacity(0.4) : (isOn ? accent : Theme.muted))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(isOn ? "Selected" : "Not selected")
    }
}

// MARK: - Status meters

struct RingMeter: View {
    let progress: Double
    let label: String
    let detail: String
    let color: Color
    var size: CGFloat = 108

    private var clamped: Double { min(max(progress, 0), 1) }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.12), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: clamped)
                    .stroke(
                        AngularGradient(colors: [color.opacity(0.55), color], center: .center),
                        style: StrokeStyle(lineWidth: 9, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.55, dampingFraction: 0.85), value: clamped)
                Circle()
                    .fill(color.opacity(0.08))
                    .frame(width: size * 0.62, height: size * 0.62)
                VStack(spacing: 1) {
                    Text("\(Int((clamped * 100).rounded()))%")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.ink)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(label.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.8)
                        .foregroundColor(Theme.muted)
                }
            }
            .frame(width: size, height: size)
            Text(detail)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Theme.muted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.Feature.surface(for: .status))
                .shadow(color: color.opacity(0.12), radius: 16, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.line, lineWidth: 1)
        )
    }
}

struct BarMeter: View {
    let title: String
    let progress: Double
    let leading: String
    let trailing: String
    let color: Color

    private var clamped: Double { min(max(progress, 0), 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.ink)
                Spacer()
                Text("\(Int((clamped * 100).rounded()))%")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.line.opacity(0.8))
                    Capsule()
                        .fill(
                            LinearGradient(colors: [color.opacity(0.7), color], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: max(6, geo.size.width * clamped))
                        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: clamped)
                }
            }
            .frame(height: 10)
            HStack {
                Text(leading)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.muted)
                Spacer()
                Text(trailing)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.muted)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.Feature.surface(for: .status))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.line, lineWidth: 1)
        )
    }
}

struct Sparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let maxV = max(values.max() ?? 1, 0.001)
            let minV = min(values.min() ?? 0, maxV)
            let span = max(maxV - minV, 0.001)
            let pts: [CGPoint] = values.enumerated().map { i, v in
                let x = values.count <= 1 ? 0 : CGFloat(i) / CGFloat(values.count - 1) * geo.size.width
                let y = geo.size.height - CGFloat((v - minV) / span) * geo.size.height * 0.92 - geo.size.height * 0.04
                return CGPoint(x: x, y: y)
            }

            ZStack {
                VStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { _ in
                        Spacer()
                        Rectangle().fill(Theme.line.opacity(0.55)).frame(height: 1)
                    }
                    Spacer(minLength: 0)
                }

                if pts.count > 1 {
                    Path { p in
                        p.move(to: CGPoint(x: pts[0].x, y: geo.size.height))
                        for pt in pts { p.addLine(to: pt) }
                        p.addLine(to: CGPoint(x: pts.last!.x, y: geo.size.height))
                        p.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.28), color.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    Path { p in
                        p.move(to: pts[0])
                        for pt in pts.dropFirst() { p.addLine(to: pt) }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                    Circle()
                        .fill(color)
                        .frame(width: 7, height: 7)
                        .shadow(color: color.opacity(0.5), radius: 4)
                        .position(pts.last!)
                }
            }
        }
        .frame(height: 72)
    }
}
