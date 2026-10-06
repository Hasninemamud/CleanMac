import SwiftUI
import AppKit

enum Theme {
    // Shared chrome — overridden per-page by Feature.pageBG / surface.
    static let bg = Color(red: 0.110, green: 0.140, blue: 0.220)
    static let rail = Color(red: 0.086, green: 0.110, blue: 0.176)
    static let surface = Color(red: 0.155, green: 0.188, blue: 0.275)
    static let surface2 = Color(red: 0.200, green: 0.235, blue: 0.325)
    static let ink = Color.white
    static let muted = Color.white.opacity(0.64)
    static let line = Color.white.opacity(0.14)
    static let accent = Color(red: 0.40, green: 0.60, blue: 0.96)
    static let accentSoft = Color(red: 0.40, green: 0.60, blue: 0.96).opacity(0.20)
    static let ok = Color(red: 0.74, green: 0.86, blue: 0.40)
    static let warn = Color(red: 0.96, green: 0.66, blue: 0.28)
    static let danger = Color(red: 1.0, green: 0.50, blue: 0.38)

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
        /// Slow atmosphere drift — not a busy loop.
        static let atmosphere = Animation.easeInOut(duration: 4.2).repeatForever(autoreverses: true)
    }

    /// Shared Mole chrome tokens (white CTA, blue link).
    enum Mole {
        static let bg = Color(red: 0.110, green: 0.140, blue: 0.220)
        static let rail = Color(red: 0.086, green: 0.110, blue: 0.176)
        static let surface = Color(red: 0.155, green: 0.188, blue: 0.275)
        static let surface2 = Color(red: 0.200, green: 0.235, blue: 0.325)
        static let ink = Color.white
        static let muted = Color.white.opacity(0.64)
        static let line = Color.white.opacity(0.14)
        static let link = Color(red: 0.52, green: 0.68, blue: 1.0)
        static let cta = Color.white
        static let ctaInk = Color(red: 0.100, green: 0.130, blue: 0.210)
    }

    /// Planet pages from mole.fit (Earth / Mars / Mercury / Jupiter / Sun).
    enum Feature {
        static let clean = Color(red: 0.40, green: 0.60, blue: 0.96)     // Earth blue
        static let apps = Color(red: 1.0, green: 0.50, blue: 0.38)        // Mars salmon
        static let analyze = Color(red: 0.82, green: 0.68, blue: 0.54)    // Jupiter tan
        static let optimize = Color(red: 0.82, green: 0.80, blue: 0.76)   // Mercury grey
        static let status = Color(red: 0.74, green: 0.86, blue: 0.40)     // Sun lime

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
            case .clean: return Color(red: 0.110, green: 0.140, blue: 0.220)    // Earth
            case .software: return Color(red: 0.095, green: 0.072, blue: 0.066)  // Mars
            case .analyze: return Color(red: 0.225, green: 0.158, blue: 0.112)   // Jupiter
            case .optimize: return Color(red: 0.145, green: 0.138, blue: 0.142)  // Mercury
            case .status: return Color(red: 0.155, green: 0.148, blue: 0.112)    // Sun
            }
        }

        static func rail(for section: AppState.NavSection) -> Color {
            switch section {
            case .clean: return Color(red: 0.086, green: 0.110, blue: 0.176)
            case .software: return Color(red: 0.075, green: 0.052, blue: 0.048)
            case .analyze: return Color(red: 0.180, green: 0.122, blue: 0.086)
            case .optimize: return Color(red: 0.110, green: 0.102, blue: 0.106)
            case .status: return Color(red: 0.122, green: 0.115, blue: 0.086)
            }
        }

        static func surface(for section: AppState.NavSection) -> Color {
            switch section {
            case .clean: return Color(red: 0.150, green: 0.190, blue: 0.285)
            case .software: return Color(red: 0.155, green: 0.118, blue: 0.112)
            case .analyze: return Color(red: 0.300, green: 0.225, blue: 0.170)
            case .optimize: return Color(red: 0.205, green: 0.196, blue: 0.190)
            case .status: return Color(red: 0.225, green: 0.212, blue: 0.168)
            }
        }

        static func surface2(for section: AppState.NavSection) -> Color {
            switch section {
            case .clean: return Color(red: 0.190, green: 0.232, blue: 0.335)
            case .software: return Color(red: 0.205, green: 0.155, blue: 0.145)
            case .analyze: return Color(red: 0.360, green: 0.275, blue: 0.210)
            case .optimize: return Color(red: 0.265, green: 0.252, blue: 0.242)
            case .status: return Color(red: 0.285, green: 0.268, blue: 0.212)
            }
        }

        static func isDark(_ section: AppState.NavSection) -> Bool { true }

        static var ctaInk: Color { Mole.ctaInk }

        /// Elevated panel fill with a light top-edge highlight.
        static func panelFill(for section: AppState.NavSection) -> LinearGradient {
            LinearGradient(
                colors: [
                    surface2(for: section).opacity(0.95),
                    surface(for: section),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Atmosphere / panels

/// Layered planet background with a slow accent drift (battery-friendly).
struct PlanetCanvas: View {
    let section: AppState.NavSection
    @State private var drift = false

    var body: some View {
        let accent = Theme.Feature.accent(for: section)
        ZStack {
            Theme.Feature.pageBG(for: section)
            RadialGradient(
                colors: [accent.opacity(drift ? 0.16 : 0.07), .clear],
                center: UnitPoint(x: drift ? 0.88 : 0.78, y: drift ? 0.12 : 0.22),
                startRadius: 12,
                endRadius: 420
            )
            RadialGradient(
                colors: [accent.opacity(0.08), .clear],
                center: UnitPoint(x: 0.12, y: 0.92),
                startRadius: 8,
                endRadius: 300
            )
            LinearGradient(
                colors: [Color.white.opacity(0.04), .clear, Color.black.opacity(0.12)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .animation(.easeInOut(duration: 0.35), value: section)
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
            .foregroundColor(Theme.Mole.ctaInk)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Color.white.opacity(disabled ? 0.4 : (configuration.isPressed ? 0.82 : 1))
            )
            .clipShape(Capsule())
            .shadow(color: Color.white.opacity(disabled || configuration.isPressed ? 0 : 0.14), radius: 10, y: 2)
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
            .background(Theme.Mole.surface.opacity(configuration.isPressed ? 0.75 : 1))
            .overlay(
                Capsule().stroke(Theme.Mole.line, lineWidth: 1)
            )
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
            Text(title)
                .font(.system(size: 12, weight: selected ? .bold : .semibold))
                .foregroundColor(selected ? Theme.Mole.ctaInk : Theme.Mole.muted)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background {
                    if selected {
                        pillFill
                    }
                }
                .scaleEffect(selected ? 1 : 0.98)
        }
        .buttonStyle(.plain)
        .animation(Theme.Motion.snappy, value: selected)
    }

    @ViewBuilder
    private var pillFill: some View {
        if let namespace {
            Capsule()
                .fill(Theme.Mole.cta)
                .shadow(color: Color.white.opacity(0.18), radius: 6, y: 1)
                .matchedGeometryEffect(id: matchID, in: namespace)
        } else {
            Capsule()
                .fill(Theme.Mole.cta)
                .shadow(color: Color.white.opacity(0.18), radius: 6, y: 1)
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
                    .animation(Theme.Motion.meter, value: values.last)

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
