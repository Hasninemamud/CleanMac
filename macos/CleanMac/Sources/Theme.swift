import SwiftUI
import AppKit

enum Theme {
    // Warm cream light theme (mockup: #F5F1E8 / #2D2926 / #D4A373 / #386641)
    static let bg = Color(red: 0.961, green: 0.945, blue: 0.910)       // #F5F1E8
    static let rail = Color(red: 0.922, green: 0.894, blue: 0.831)     // #EBE4D4
    static let surface = Color(red: 1.0, green: 0.984, blue: 0.957)    // #FFFBF4
    static let surface2 = Color(red: 0.929, green: 0.902, blue: 0.847) // #EDE6D8
    static let ink = Color(red: 0.176, green: 0.161, blue: 0.149)      // #2D2926
    static let muted = Color(red: 0.478, green: 0.439, blue: 0.400)    // #7A7066
    static let line = Color(red: 0.176, green: 0.161, blue: 0.149).opacity(0.12)
    static let accent = Color(red: 0.831, green: 0.639, blue: 0.451)   // #D4A373
    static let accentSoft = Color(red: 0.831, green: 0.639, blue: 0.451).opacity(0.16)
    static let ok = Color(red: 0.220, green: 0.400, blue: 0.255)       // #386641
    static let warn = Color(red: 0.78, green: 0.55, blue: 0.22)
    static let danger = Color(red: 0.69, green: 0.26, blue: 0.18)

    /// Mole-style dark navy chrome for Clean / Optimize heroes.
    enum Mole {
        static let bg = Color(red: 0.110, green: 0.145, blue: 0.231)       // #1C253B
        static let rail = Color(red: 0.090, green: 0.118, blue: 0.188)     // #171E30
        static let surface = Color(red: 0.145, green: 0.184, blue: 0.275)  // #252F46
        static let surface2 = Color(red: 0.180, green: 0.220, blue: 0.320) // #2E3851
        static let ink = Color.white
        static let muted = Color.white.opacity(0.55)
        static let line = Color.white.opacity(0.12)
        static let link = Color(red: 0.45, green: 0.62, blue: 1.0)
        static let cta = Color.white
        static let ctaInk = Color(red: 0.110, green: 0.145, blue: 0.231)
    }

    /// Unique palette per nav feature (full-page color identity).
    enum Feature {
        static let clean = Color(red: 0.35, green: 0.55, blue: 0.98)      // blue
        static let apps = Color(red: 0.08, green: 0.65, blue: 0.58)       // teal
        static let analyze = Color(red: 0.55, green: 0.35, blue: 0.90)    // purple
        static let optimize = Color(red: 0.96, green: 0.55, blue: 0.22)   // orange
        static let status = Color(red: 0.22, green: 0.55, blue: 0.32)     // green

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
            case .clean: return Color(red: 0.10, green: 0.14, blue: 0.26)      // navy
            case .software: return Color(red: 0.90, green: 0.96, blue: 0.95)   // mint
            case .analyze: return Color(red: 0.94, green: 0.91, blue: 0.98)    // lilac
            case .optimize: return Color(red: 0.17, green: 0.11, blue: 0.07)   // amber dark
            case .status: return Color(red: 0.92, green: 0.96, blue: 0.93)     // sage
            }
        }

        static func rail(for section: AppState.NavSection) -> Color {
            switch section {
            case .clean: return Color(red: 0.08, green: 0.11, blue: 0.20)
            case .software: return Color(red: 0.78, green: 0.92, blue: 0.90)
            case .analyze: return Color(red: 0.86, green: 0.80, blue: 0.95)
            case .optimize: return Color(red: 0.13, green: 0.08, blue: 0.05)
            case .status: return Color(red: 0.82, green: 0.91, blue: 0.85)
            }
        }

        static func surface(for section: AppState.NavSection) -> Color {
            switch section {
            case .clean: return Mole.surface
            case .software: return Color(red: 0.97, green: 1.0, blue: 0.99)
            case .analyze: return Color(red: 0.99, green: 0.97, blue: 1.0)
            case .optimize: return Color(red: 0.22, green: 0.15, blue: 0.10)
            case .status: return Color(red: 0.98, green: 1.0, blue: 0.98)
            }
        }

        static func surface2(for section: AppState.NavSection) -> Color {
            switch section {
            case .clean: return Mole.surface2
            case .software: return Color(red: 0.82, green: 0.93, blue: 0.91)
            case .analyze: return Color(red: 0.90, green: 0.85, blue: 0.96)
            case .optimize: return Color(red: 0.28, green: 0.18, blue: 0.12)
            case .status: return Color(red: 0.86, green: 0.93, blue: 0.88)
            }
        }

        static func isDark(_ section: AppState.NavSection) -> Bool {
            section == .clean || section == .optimize
        }
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
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .fill(Theme.bg) // cream
                    .overlay {
                        Text("C")
                            .font(.system(size: size * 0.45, weight: .bold))
                            .foregroundColor(Theme.ink)
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
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
            .foregroundColor(Theme.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Theme.accent.opacity(disabled ? 0.4 : (configuration.isPressed ? 0.85 : 1)))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Theme.ink.opacity(0.18), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Theme.ink.opacity(0.22), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .fixedSize()
    }
}

struct SegmentPill: View {
    let title: String
    let selected: Bool
    var dark = false
    var accent: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(selected
                    ? (dark ? .white : Theme.ink)
                    : (dark ? Theme.Mole.muted : Theme.muted))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(selected
                    ? (dark ? (accent ?? Theme.Mole.cta) : (accent?.opacity(0.22) ?? Theme.surface))
                    : Color.clear)
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

    var body: some View {
        Button {
            if !disabled { isOn.toggle() }
        } label: {
            Image(systemName: isOn ? "checkmark.square.fill" : "square")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(disabled ? Theme.muted.opacity(0.4) : (isOn ? Theme.accent : Theme.muted))
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
                .fill(Theme.surface)
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
                .fill(Theme.surface)
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
                // grid
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
