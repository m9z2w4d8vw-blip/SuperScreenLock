import SwiftUI

struct SetupView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Super Screen Lock")
                        .font(Theme.display(30))
                        .foregroundStyle(Theme.ivory)
                    Text("Set a daily screen time limit. Once you hit it, every app stays locked until you scan \(model.biometryName) as many times as you choose.")
                        .font(.body)
                        .foregroundStyle(Theme.steel)
                        .fixedSize(horizontal: false, vertical: true)
                }

                DialView(total: 10, filled: 4)
                    .frame(width: 168, height: 168)
                    .frame(maxWidth: .infinity)

                VStack(spacing: 0) {
                    SetupStep(
                        number: 1,
                        title: "Allow Screen Time access",
                        detail: "Lets Super Screen Lock count today's screen time and lock apps. Your usage never leaves this iPhone.",
                        status: model.authorization == .approved ? "Allowed" : nil,
                        buttonTitle: model.authorization == .denied ? "Try again" : "Allow"
                    ) {
                        Task { await model.requestScreenTime() }
                    }
                    Hairline()
                    SetupStep(
                        number: 2,
                        title: "Allow notifications",
                        detail: "Apple's lock screen can't run \(model.biometryName) itself, so it sends a notification that brings you here to scan.",
                        status: notificationStatus,
                        buttonTitle: "Allow"
                    ) {
                        Task { await model.requestNotifications() }
                    }
                }
                .padding(.horizontal, 16)
                .background(Theme.plate, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                if model.authorization == .denied {
                    Text("Screen Time access was declined. Tap Try again, or check Settings › Screen Time.")
                        .font(.footnote)
                        .foregroundStyle(Theme.steel)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(24)
        }
    }

    private var notificationStatus: String? {
        switch model.notifications {
        case .allowed: return "Allowed"
        case .denied: return "Off"
        case .notDetermined, .unknown: return nil
        }
    }
}

struct SetupStep: View {
    let number: Int
    let title: String
    let detail: String
    let status: String?
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(Theme.display(16))
                .foregroundStyle(Theme.brass)
                .frame(width: 30, height: 30)
                .overlay(Circle().stroke(Theme.brass.opacity(0.6), lineWidth: 1))
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.ivory)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Theme.steel)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if let status {
                Text(status)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.brass)
                    .padding(.top, 4)
            } else {
                Button(action: action) {
                    Text(buttonTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.enamel)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Theme.brass, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 16)
    }
}
