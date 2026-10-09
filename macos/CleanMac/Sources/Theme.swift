import SwiftUI
import AppKit

enum Theme {
    /// Cream (light) / chocolate (dark) — flipped by the sun toggle.
    static var useDark: Bool = UserDefaults.standard.object(forKey: "appearanceDark") as? Bool ?? true

    // Shared chrome (mock: unified cream/chocolate, planet accents on icons only).
    static var bg: Color {
        useDark ? Color(red: 0.102, green: 0.071, blue: 0.051) : Color(red: 0.992, green: 0.973, blue: 0.890)
    }
    static var rail: Color {
        useDark ? Color(red: 0.086, green: 0.059, blue: 0.043) : Color(red: 0.980, green: 0.953, blue: 0.855)
    }
    static var surface: Color {
        useDark ? Color(red: 0.145, green: 0.110, blue: 0.086) : Color(red: 1.0, green: 0.995, blue: 0.975)
    }
    static var surface2: Color {
        useDark ? Color(red: 0.185, green: 0.145, blue: 0.115) : Color(red: 0.965, green: 0.930, blue: 0.820)
    }
    static var ink: Color {
        useDark ? Color(red: 0.992, green: 0.961, blue: 0.902) : Color(red: 0.220, green: 0.145, blue: 0.100)
    }
    static var muted: Color {
        useDark ? Color(red: 0.992, green: 0.961, blue: 0.902).opacity(0.58) : Color(red: 0.420, green: 0.320, blue: 0.240)
    }
    static var line: Color {
        useDark ? Color.white.opacity(0.10) : Color(red: 0.220, green: 0.145, blue: 0.100).opacity(0.12)
    }
    static var accent: Color { Color(red: 0.83, green: 0.36, blue: 0.28) } // terracotta
    static var accentSoft: Color { accent.opacity(0.18) }
    static var ok: Color { Color(red: 0.42, green: 0.58, blue: 0.48) }
    static var warn: Color { Color(red: 0.85, green: 0.66, blue: 0.35) }
    static var danger: Color { Color(red: 0.83, green: 0.36, blue: 0.28) }
    /// Sandy primary CTA (dark Scan Mac) / terracotta fill when light.
    static var ctaFill: Color {
        useDark ? Color(red: 0.851, green: 0.663, blue: 0.451) : Color(red: 0.83, green: 0.36, blue: 0.28)
    }
    static var ctaInk: Color {
        useDark ? Color(red: 0.180, green: 0.110, blue: 0.070) : Color.white
    }
    static var footerBar: Color {
        useDark ? Color(red: 0.160, green: 0.120, blue: 0.090) : Color(red: 0.925, green: 0.870, blue: 0.755)
    }

    enum Radius {
        static let sm: CGFloat = 10
        static let md: CGFloat = 14
        static let card: CGFloat = 16
        static let lg: CGFloat = 20
    }

    enum Typeface {
        static func hero(_ size: CGFloat = 32) -> Font {
            .system(size: size, weight: .bold, design: .rounded)
        }
        static func title(_ size: CGFloat = 20) -> Font {
            .system(size: size, weight: .bold)
        }
        static func body(_ size: CGFloat = 13) -> Font {
            .system(size: size, weight: .medium)
        }
        static func caption(_ size: CGFloat = 11) -> Font {
            .system(size: size, weight: .semibold)
        }
        static func micro(_ size: CGFloat = 10) -> Font {
            .system(size: size, weight: .bold)
        }
    }

    enum Motion {
        static let section = Animation.spring(response: 0.40, dampingFraction: 0.86)
        static let snappy = Animation.spring(response: 0.32, dampingFraction: 0.84)
        static let meter = Animation.spring(response: 0.55, dampingFraction: 0.86)
        static let press = Animation.spring(response: 0.26, dampingFraction: 0.72)
        static let atmosphere = Animation.easeInOut(duration: 4.2).repeatForever(autoreverses: true)
    }

    /// Aliases so existing Mole.* call sites track cream/chocolate.
    enum Mole {
        static var bg: Color { Theme.bg }
        static var rail: Color { Theme.rail }
        static var surface: Color { Theme.surface }
        static var surface2: Color { Theme.surface2 }
        static var ink: Color { Theme.ink }
        static var muted: Color { Theme.muted }
        static var line: Color { Theme.line }
        static var link: Color { Theme.useDark ? Color(red: 0.75, green: 0.62, blue: 0.45) : Color(red: 0.35, green: 0.25, blue: 0.18) }
        static var cta: Color { Theme.ctaFill }
        static var ctaInk: Color { Theme.ctaInk }
    }

    /// Planet icon accents (nav dots) — page chrome is shared cream/chocolate.
    enum Feature {
        static let clean = Color(red: 0.45, green: 0.62, blue: 0.78)     // Earth
        static let apps = Color(red: 0.82, green: 0.38, blue: 0.30)       // Mars
        static let analyze = Color(red: 0.72, green: 0.58, blue: 0.42)    // Jupiter
        static let optimize = Color(red: 0.72, green: 0.70, blue: 0.66)   // Mercury
        static let status = Color(red: 0.88, green: 0.72, blue: 0.28)     // Sun

        static func accent(for section: AppState.NavSection) -> Color {
            switch section {
            case .clean: return clean
            case .software: return apps
            case .analyze: return analyze
            case .optimize: return optimize
            case .status: return status
            }
        }

        static func pageBG(for section: AppState.NavSection) -> Color { Theme.bg }
        static func rail(for section: AppState.NavSection) -> Color { Theme.rail }
        static func surface(for section: AppState.NavSection) -> Color { Theme.surface }
        static func surface2(for section: AppState.NavSection) -> Color { Theme.surface2 }
        static func isDark(_ section: AppState.NavSection) -> Bool { Theme.useDark }
        static var ctaInk: Color { Theme.ctaInk }

        static func panelFill(for section: AppState.NavSection) -> LinearGradient {
            LinearGradient(
                colors: [surface2(for: section).opacity(0.95), surface(for: section)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Atmosphere / panels

/// Soft cream/chocolate canvas with a faint section accent wash.
struct PlanetCanvas: View {
    let section: AppState.NavSection
    @State private var drift = false

    var body: some View {
        let accent = Theme.Feature.accent(for: section)
        let wash = Theme.useDark ? 0.10 : 0.06
        ZStack {
            Theme.bg
            RadialGradient(
                colors: [accent.opacity(drift ? wash : wash * 0.45), .clear],
                center: UnitPoint(x: drift ? 0.82 : 0.72, y: drift ? 0.18 : 0.28),
                startRadius: 20,
                endRadius: 380
            )
            LinearGradient(
                colors: [
                    Theme.useDark ? Color.white.opacity(0.03) : Color.white.opacity(0.35),
                    .clear,
                    Theme.useDark ? Color.black.opacity(0.18) : Color(red: 0.22, green: 0.14, blue: 0.10).opacity(0.04),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .animation(.easeInOut(duration: 0.35), value: section)
        .animation(.easeInOut(duration: 0.35), value: Theme.useDark)
        .onAppear {
            withAnimation(Theme.Motion.atmosphere) { drift = true }
        }
    }
}

struct GlassPanelModifier: ViewModifier {
    let section: AppState.NavSection
    var radius: CGFloat = Theme.Radius.card
    var accentStroke: Bool = true

    func body(content: Content) -> some View {
        let accent = Theme.Feature.accent(for: section)
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Theme.Feature.panelFill(for: section))
                    .shadow(color: accent.opacity(0.08), radius: 14, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.16),
                                accent.opacity(accentStroke ? 0.22 : 0.10),
                                Color.white.opacity(0.05),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

extension View {
    func glassPanel(for section: AppState.NavSection, radius: CGFloat = Theme.Radius.card) -> some View {
        modifier(GlassPanelModifier(section: section, radius: radius))
    }

    func pageEnter() -> some View { modifier(PageEnterModifier()) }

    func listAppear(index: Int) -> some View {
        modifier(ListAppearModifier(index: index))
    }
}

/// Soft enter animation for page roots.
struct PageEnterModifier: ViewModifier {
    @State private var ready = false
    func body(content: Content) -> some View {
        content
            .opacity(ready ? 1 : 0)
            .offset(y: ready ? 0 : 14)
            .scaleEffect(ready ? 1 : 0.988)
            .onAppear {
                withAnimation(.spring(response: 0.46, dampingFraction: 0.88)) { ready = true }
            }
    }
}

struct ListAppearModifier: ViewModifier {
    let index: Int
    @State private var ready = false
    func body(content: Content) -> some View {
        content
            .opacity(ready ? 1 : 0)
            .offset(y: ready ? 0 : 8)
            .onAppear {
                let delay = min(Double(index) * 0.035, 0.28)
                withAnimation(.spring(response: 0.38, dampingFraction: 0.88).delay(delay)) {
                    ready = true
                }
            }
    }
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
        .shadow(color: Color.white.opacity(0.12), radius: 6, y: 1)
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
            .foregroundColor(disabled ? Theme.muted : Theme.ctaInk)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Theme.ctaFill.opacity(disabled ? 0.4 : (configuration.isPressed ? 0.85 : 1)))
            .clipShape(Capsule())
            .shadow(color: Theme.ctaFill.opacity(disabled || configuration.isPressed ? 0 : 0.28), radius: 10, y: 2)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(Theme.Motion.press, value: configuration.isPressed)
    }
}

struct SoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(Theme.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Theme.surface.opacity(configuration.isPressed ? 0.75 : 1))
            .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(Theme.Motion.press, value: configuration.isPressed)
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
            .background(Theme.danger.opacity(configuration.isPressed ? 0.8 : 1))
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(Theme.Motion.press, value: configuration.isPressed)
            .fixedSize()
    }
}

struct SegmentPill: View {
    let title: String
    let selected: Bool
    var dark = true
    var accent: Color? = nil
    var namespace: Namespace.ID? = nil
    var matchID: String = "segmentPill"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let accent {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [accent.opacity(0.95), accent.opacity(0.55)],
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: 8
                            )
                        )
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color.white.opacity(Theme.useDark ? 0.15 : 0.35), lineWidth: 0.5))
                }
                Text(title)
                    .font(.system(size: 12, weight: selected ? .bold : .semibold))
                    .foregroundColor(selected ? Theme.ink : Theme.muted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                if selected { pillFill }
            }
            .scaleEffect(selected ? 1 : 0.98)
        }
        .buttonStyle(.plain)
        .animation(Theme.Motion.snappy, value: selected)
    }

    @ViewBuilder
    private var pillFill: some View {
        let fill = Theme.useDark ? Color.white.opacity(0.10) : Color.white
        if let namespace {
            Capsule()
                .fill(fill)
                .shadow(color: Color.black.opacity(Theme.useDark ? 0.25 : 0.06), radius: 6, y: 1)
                .matchedGeometryEffect(id: matchID, in: namespace)
        } else {
            Capsule()
                .fill(fill)
                .shadow(color: Color.black.opacity(Theme.useDark ? 0.25 : 0.06), radius: 6, y: 1)
        }
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
                .symbolEffect(.bounce, value: isOn)
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
                    .stroke(color.opacity(0.14), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: clamped)
                    .stroke(
                        AngularGradient(colors: [color.opacity(0.5), color], center: .center),
                        style: StrokeStyle(lineWidth: 9, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(Theme.Motion.meter, value: clamped)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [color.opacity(0.14), color.opacity(0.04)],
                            center: .center,
                            startRadius: 2,
                            endRadius: size * 0.35
                        )
                    )
                    .frame(width: size * 0.62, height: size * 0.62)
                VStack(spacing: 1) {
                    Text("\(Int((clamped * 100).rounded()))%")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.ink)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(Theme.Motion.meter, value: clamped)
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
        .glassPanel(for: .status, radius: Theme.Radius.lg)
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
                    .animation(Theme.Motion.meter, value: clamped)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.line.opacity(0.8))
                    Capsule()
                        .fill(
                            LinearGradient(colors: [color.opacity(0.7), color], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: max(6, geo.size.width * clamped))
                        .animation(Theme.Motion.meter, value: clamped)
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
        .glassPanel(for: .status, radius: Theme.Radius.md)
    }
}

struct Sparkline: View {
    let values: [Double]
    let color: Color
    /// When true (default), Y axis is always 0…1 so % metrics don't auto-zoom into noise.
    var fixedScale: Bool = true
    var lineWidth: CGFloat = 1.6

    private var samples: [Double] {
        let raw = values.map { min(max($0, 0), 1) }
        if raw.isEmpty { return [0, 0] }
        if raw.count == 1 { return [raw[0], raw[0]] }
        return Array(raw.suffix(24))
    }

    var body: some View {
        GeometryReader { geo in
            let vals = samples
            let maxV = fixedScale ? 1.0 : max(vals.max() ?? 1, 0.001)
            let minV = fixedScale ? 0.0 : (vals.min() ?? 0)
            let span = max(maxV - minV, 0.001)
            let h = max(geo.size.height, 1)
            let w = max(geo.size.width, 1)
            let pts: [CGPoint] = vals.enumerated().map { i, v in
                let x = CGFloat(i) / CGFloat(vals.count - 1) * w
                let y = h - CGFloat((v - minV) / span) * (h * 0.88) - h * 0.06
                return CGPoint(x: x, y: y)
            }

            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h * 0.5))
                    p.addLine(to: CGPoint(x: w, y: h * 0.5))
                }
                .stroke(Theme.line.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

                Path { p in
                    p.move(to: CGPoint(x: pts[0].x, y: h))
                    for pt in pts { p.addLine(to: pt) }
                    p.addLine(to: CGPoint(x: pts.last!.x, y: h))
                    p.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.30), color.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                Path { p in
                    p.move(to: pts[0])
                    for pt in pts.dropFirst() { p.addLine(to: pt) }
                }
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))

                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
                    .position(pts.last!)
            }
            .clipped()
        }
        .accessibilityHidden(true)
    }
}
