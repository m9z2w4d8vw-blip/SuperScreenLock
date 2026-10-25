import Combine
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            Theme.enamel.ignoresSafeArea()
            content
        }
        .fullScreenCover(item: $model.unlockRequest) { request in
            UnlockView(request: request, requiredScans: model.saved.requiredScans, method: model.biometryName)
                .environmentObject(model)
        }
        .alert("Super Screen Lock", isPresented: alertShown) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.alertMessage ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: .sslOpenedFromNotification)) { _ in
            model.refresh()
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

    private var alertShown: Binding<Bool> {
        Binding(
            get: { model.alertMessage != nil },
            set: { shown in
                if !shown { model.alertMessage = nil }
            }
        )
    }
}
