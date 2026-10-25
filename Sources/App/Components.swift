import SwiftUI

/// The safe dial. One tick per required scan; filled ticks are brass.
struct DialView: View {
    let total: Int
    let filled: Int
    var dimmed = false

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = side / 2 - 1
            let ring = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            context.stroke(Path(ellipseIn: ring), with: .color(Theme.brass.opacity(dimmed ? 0.3 : 0.6)), lineWidth: 1.5)

            let count = max(total, 1)
            let outer = radius - 12
            let length = radius * (count > 30 ? 0.09 : 0.14)
            let inner = outer - length
            let spacing = 2 * CGFloat.pi * outer / CGFloat(count)
            let width = max(2, min(8, spacing * 0.3))

            for index in 0..<count {
                let angle = Double(index) / Double(count) * 2 * Double.pi - Double.pi / 2
                let dx = CGFloat(cos(angle))
                let dy = CGFloat(sin(angle))
                var tick = Path()
                tick.move(to: CGPoint(x: center.x + dx * inner, y: center.y + dy * inner))
                tick.addLine(to: CGPoint(x: center.x + dx * outer, y: center.y + dy * outer))
                let color: Color = index < filled ? Theme.brass : Theme.steel.opacity(dimmed ? 0.2 : 0.38)
                context.stroke(tick, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
            }
        }
        .accessibilityHidden(true)
    }
}

/// Minus, value, plus. Also adjustable with VoiceOver swipes.
struct ValueStepper: View {
    let value: String
    let label: String
    let canDecrement: Bool
    let canIncrement: Bool
    let decrement: () -> Void
    let increment: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            stepButton(symbol: "minus", enabled: canDecrement, action: decrement)
            Text(value)
                .font(.system(.title3).weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.ivory)
                .frame(minWidth: 70)
            stepButton(symbol: "plus", enabled: canIncrement, action: increment)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                if canIncrement { increment() }
            case .decrement:
                if canDecrement { decrement() }
            @unknown default:
                break
            }
        }
    }

    private func stepButton(symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(enabled ? Theme.brass : Theme.steel.opacity(0.4))
                .frame(width: 34, height: 34)
                .overlay(Circle().stroke(enabled ? Theme.brass.opacity(0.7) : Theme.steel.opacity(0.25), lineWidth: 1.2))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

/// A row on the control plate: title and detail on the left, a control on the right.
struct PlateRow<Trailing: View>: View {
    let title: String
    var detail: String? = nil
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.ivory)
                if let detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(Theme.steel)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.vertical, 14)
    }
}

struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.enamel)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.brass, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct QuietButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.ivory)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Theme.brass.opacity(0.55), lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(height: 1)
    }
}
