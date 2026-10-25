import SwiftUI

struct SetupView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Hero(
                    symbol: "lock.shield",
                    headline: "Lock your apps after a daily limit.",
                    message: "Pick how much screen time you get each day. Once it's used up, every app stays locked until you scan \(model.biometryName) as many times as you choose."
                )
                Rule()
                    .padding(.top, 36)
                CheckRow(
                    title: "Allow Screen Time access",
                    detail: screenTimeDetail,
                    isOn: model.authorization == .approved
                ) {
                    guard model.authorization != .approved else { return }
                    Task { await model.requestScreenTime() }
                }
                Rule()
                CheckRow(
                    title: "Allow notifications",
                    detail: "Apple's lock screen can't run \(model.biometryName) itself, so it sends a notification that brings you here to scan.",
                    isOn: model.notifications == .allowed
                ) {
                    guard model.notifications != .allowed else { return }
                    Task { await model.requestNotifications() }
                }
                Rule()
                Text("Tap each box to allow it. Your screen time never leaves this iPhone.")
                    .font(Theme.small)
                    .foregroundStyle(Theme.mint)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 18)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 44)
        }
        .scrollIndicators(.hidden)
    }

    private var screenTimeDetail: String {
        if model.authorization == .denied {
            return "It was declined. Tap to ask again, or check Settings › Screen Time."
        }
        return "Lets Super Screen Lock count today's screen time and lock apps."
    }
}
