import Combine
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            Theme.green.ignoresSafeArea()
            content
        }
        .fullScreenCover(item: $model.unlockRequest) { request in
            UnlockView(
                request: request,
                requiredScans: model.saved.requiredScans,
                method: model.biometryName,
                restartOnFail: model.saved.restartOnFail
            )
                .environmentObject(model)
        }
        .alert("Super Screen Lock", isPresented: $model.isAlertShown) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.alertMessage)
        }
        .onReceive(NotificationCenter.default.publisher(for: .sslOpenedFromNotification)) { _ in
            model.refresh(reason: "Opened from a notification")
        }
        .task {
            await model.settle()
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.authorization == .approved && model.notifications != .notDetermined {
            HomeView()
        } else if model.hasSettled || model.authorization != .notDetermined {
            SetupView()
        }
    }
}
