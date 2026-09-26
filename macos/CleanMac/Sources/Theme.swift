import SwiftUI
import AppKit

enum Theme {
    static let bg = Color(red: 0.102, green: 0.082, blue: 0.055)
    static let rail = Color(red: 0.078, green: 0.063, blue: 0.043)
    static let surface = Color(red: 0.141, green: 0.110, blue: 0.078)
    static let surface2 = Color(red: 0.18, green: 0.14, blue: 0.10)
    static let ink = Color(red: 0.953, green: 0.918, blue: 0.847)
    static let muted = Color(red: 0.72, green: 0.64, blue: 0.52)
    static let line = Color.white.opacity(0.12)
    static let accent = Color(red: 0.835, green: 0.608, blue: 0.247)
    static let accentSoft = Color(red: 0.835, green: 0.608, blue: 0.247).opacity(0.22)
    static let ok = Color(red: 0.45, green: 0.76, blue: 0.55)
    static let warn = Color(red: 0.90, green: 0.72, blue: 0.36)
    static let danger = Color(red: 0.92, green: 0.42, blue: 0.38)
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
                RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
                    .fill(Theme.accent)
                    .overlay {
                        Text("C")
                            .font(.system(size: size * 0.45, weight: .bold))
                            .foregroundColor(Theme.bg)
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
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
            .foregroundColor(Theme.bg)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Theme.accent.opacity(disabled ? 0.4 : (configuration.isPressed ? 0.85 : 1)))
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
            .background(Theme.surface2)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Theme.line, lineWidth: 1)
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(selected ? Theme.ink : Theme.muted)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(selected ? Theme.surface : Color.clear)
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
    var size: CGFloat = 118

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(Theme.line, lineWidth: 10)
                Circle()
                    .trim(from: 0, to: min(max(progress, 0), 1))
                    .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.55), value: progress)
                VStack(spacing: 2) {
                    Text("\(Int((min(max(progress, 0), 1) * 100).rounded()))%")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.ink)
                        .monospacedDigit()
                    Text(label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.muted)
                }
            }
            .frame(width: size, height: size)
            Text(detail)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Theme.muted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: size + 40)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.ink)
                Spacer()
                Text("\(Int((min(max(progress, 0), 1) * 100).rounded()))%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.line)
                    Capsule()
                        .fill(color)
                        .frame(width: max(4, geo.size.width * min(max(progress, 0), 1)))
                        .animation(.easeInOut(duration: 0.45), value: progress)
                }
            }
            .frame(height: 8)
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
        .padding(14)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
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
            let pts: [CGPoint] = values.enumerated().map { i, v in
                let x = values.count <= 1 ? 0 : CGFloat(i) / CGFloat(values.count - 1) * geo.size.width
                let y = geo.size.height - CGFloat(v / maxV) * geo.size.height
                return CGPoint(x: x, y: y)
            }
            Path { p in
                guard let first = pts.first else { return }
                p.move(to: first)
                for pt in pts.dropFirst() { p.addLine(to: pt) }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .frame(height: 36)
    }
}
