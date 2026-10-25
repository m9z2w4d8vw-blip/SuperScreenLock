import FamilyControls
import ManagedSettings
import SwiftUI

/// Icon, giant headline, body text. The top of every screen.
struct Hero: View {
    let symbol: String
    let headline: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HeaderGlyph(symbol: symbol)
            Text(headline)
                .font(Theme.headline(58))
                .foregroundStyle(Color.white)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 18)
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .font(Theme.body)
                .foregroundStyle(Theme.mint)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct HeaderGlyph: View {
    let symbol: String

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 34, weight: .regular))
            .foregroundStyle(Color.white)
            .accessibilityHidden(true)
    }
}

/// A one-pixel divider in the lighter green.
struct Rule: View {
    var body: some View {
        Rectangle()
            .fill(Theme.rule)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

/// White outline when off; white fill with a green check when on.
struct Checkbox: View {
    let isOn: Bool
    var size: CGFloat = 22

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
        shape
            .fill(isOn ? Color.white : Color.clear)
            .overlay(shape.strokeBorder(Color.white, lineWidth: isOn ? 0 : 1.6))
            .overlay(
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.58, weight: .heavy))
                    .foregroundStyle(Theme.green)
                    .opacity(isOn ? 1 : 0)
            )
            .frame(width: size, height: size)
            .animation(.easeOut(duration: 0.16), value: isOn)
            .accessibilityHidden(true)
    }
}

/// Checkbox, a semibold label, and helper text underneath. The whole row is tappable.
struct CheckRow: View {
    let title: String
    var detail: String? = nil
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Checkbox(isOn: isOn)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(Theme.label)
                        .foregroundStyle(Color.white)
                        .fixedSize(horizontal: false, vertical: true)
                    if let detail {
                        Text(detail)
                            .font(Theme.small)
                            .foregroundStyle(Theme.mint)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }
}

/// Label, a big DIN number with minus and plus, helper text.
struct ValueRow: View {
    let title: String
    let detail: String
    let value: String
    let canDecrement: Bool
    let canIncrement: Bool
    let decrement: () -> Void
    let increment: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Theme.label)
                .foregroundStyle(Color.white)
            HStack(alignment: .center, spacing: 10) {
                Text(value)
                    .font(Theme.headline(42))
                    .monospacedDigit()
                    .foregroundStyle(Color.white)
                Spacer(minLength: 8)
                SquareButton(symbol: "minus", enabled: canDecrement, action: decrement)
                SquareButton(symbol: "plus", enabled: canIncrement, action: increment)
            }
            Text(detail)
                .font(Theme.small)
                .foregroundStyle(Theme.mint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 18)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
        .accessibilityHint(detail)
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
}

struct SquareButton: View {
    let symbol: String
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.white.opacity(enabled ? 1 : 0.35))
                .frame(width: 44, height: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(Color.white.opacity(enabled ? 1 : 0.3), lineWidth: 1.6)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

struct Choice<Value: Hashable>: Identifiable {
    let value: Value
    let label: String
    var id: Value { value }
}

/// A row of outlined boxes; the chosen one is filled white.
struct ChoiceRow<Value: Hashable>: View {
    let title: String
    var detail: String? = nil
    let options: [Choice<Value>]
    @Binding var selection: Value

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(Theme.label)
                .foregroundStyle(Color.white)
            HStack(spacing: 8) {
                ForEach(options) { option in
                    let selected = option.value == selection
                    Button {
                        selection = option.value
                    } label: {
                        Text(option.label)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(selected ? Theme.green : Color.white)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(selected ? Color.white : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .strokeBorder(Color.white, lineWidth: selected ? 0 : 1.6)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? [.isSelected] : [])
                }
            }
            if let detail {
                Text(detail)
                    .font(Theme.small)
                    .foregroundStyle(Theme.mint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 18)
    }
}

/// White button with green text.
struct PrimaryButton: View {
    let title: String
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.label)
                .foregroundStyle(Theme.green)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.white.opacity(enabled ? 1 : 0.55))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

/// White outline button.
struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.label)
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity, minHeight: 54)
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(Color.white, lineWidth: 1.6)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Small underlined text button, like a link.
struct TextLink: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.small.weight(.semibold))
                .underline()
                .foregroundStyle(Color.white)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// An app's real icon and name, drawn by iOS from its Screen Time token.
struct AppTile: View {
    let token: ApplicationToken
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Label(token)
                    .labelStyle(.iconOnly)
                    .scaleEffect(2)
                    .frame(width: 52, height: 52)
                Label(token)
                    .labelStyle(.titleOnly)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(selected ? Theme.green : Color.white)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selected ? Color.white : Color.white.opacity(0.08))
            )
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.green)
                        .padding(5)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

/// Opens the system app list for anything that isn't in the grid yet.
struct OtherAppTile: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 52, height: 52)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    )
                Text("Other app")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Pick another app")
    }
}
