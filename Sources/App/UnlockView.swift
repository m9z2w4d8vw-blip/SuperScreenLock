import FamilyControls
import ManagedSettings
import SwiftUI

/// The scan screen. The dial fills one tick per scan.
struct UnlockView: View {
    @EnvironmentObject private var model: AppModel
    @StateObject private var session: ScanSession
    @State private var target: UnlockRequest.Target
    @State private var result: String?

    init(request: UnlockRequest, requiredScans: Int, method: String) {
        _session = StateObject(wrappedValue: ScanSession(required: requiredScans, method: method))
        _target = State(initialValue: request.target)
    }

    var body: some View {
        ZStack {
            Theme.enamel.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button(result == nil ? "Cancel" : "Done") {
                        close()
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.steel)
                    Spacer()
                }
                .padding(.horizontal, 22)
                .padding(.top, 14)

                Spacer(minLength: 16)
                heading
                Spacer(minLength: 28)

                ZStack {
                    DialView(total: session.required, filled: session.completed)
                    VStack(spacing: 0) {
                        Text("\(session.completed)")
                            .font(Theme.display(68))
                            .monospacedDigit()
                            .foregroundStyle(Theme.ivory)
                            .contentTransition(.numericText())
                        Text("of \(session.required)")
                            .font(.headline)
                            .foregroundStyle(Theme.steel)
                    }
                }
                .frame(width: 264, height: 264)
                .animation(.easeOut(duration: 0.22), value: session.completed)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(session.completed) of \(session.required) scans done")

                Spacer(minLength: 24)
                Text(statusLine)
                    .font(.body)
                    .foregroundStyle(Theme.steel)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 32)
                    .frame(minHeight: 68, alignment: .top)
                Spacer(minLength: 16)

                buttons
                    .padding(.horizontal, 22)
                    .padding(.bottom, 20)
            }
        }
        .task {
            session.onFinish = { finish() }
            try? await Task.sleep(nanoseconds: 600_000_000)
            session.start()
        }
        .onDisappear {
            session.stop()
        }
    }

    // MARK: Pieces

    private var heading: some View {
        VStack(spacing: 10) {
            switch target {
            case .app(let token):
                Text("Unlocking")
                    .font(.subheadline)
                    .foregroundStyle(Theme.steel)
                Label(token)
                    .labelStyle(.titleAndIcon)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Theme.ivory)
                Text("for \(Format.spokenDuration(minutes: model.saved.unlockMinutes))")
                    .font(.subheadline)
                    .foregroundStyle(Theme.steel)
            case .allApps:
                Text("Unlocking")
                    .font(.subheadline)
                    .foregroundStyle(Theme.steel)
                Text("All apps")
                    .font(Theme.display(26))
                    .foregroundStyle(Theme.ivory)
                Text("for \(Format.spokenDuration(minutes: model.saved.unlockMinutes))")
                    .font(.subheadline)
                    .foregroundStyle(Theme.steel)
            case .saveSettings:
                Text("Save your changes")
                    .font(Theme.display(24))
                    .foregroundStyle(Theme.ivory)
                Text("Today's limit is used up, so changes take the same scans as unlocking.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.steel)
            case .turnOff:
                Text("Turn off the lock")
                    .font(Theme.display(24))
                    .foregroundStyle(Theme.ivory)
                Text("Today's limit is used up, so turning off takes the same scans as unlocking.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.steel)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 28)
    }

    private var statusLine: String {
        if let result { return result }
        let next = min(session.completed + 1, session.required)
        switch session.phase {
        case .idle:
            return model.biometryName == "Touch ID"
                ? "Rest your finger on Touch ID. Scanning starts in a moment."
                : "Hold your iPhone like you're unlocking it. Scanning starts in a moment."
        case .scanning:
            return session.usingPasscode
                ? "Enter your passcode for scan \(next) of \(session.required)."
                : "Scan \(next) of \(session.required)"
        case .paused(let message):
            return message
        case .finished:
            return "Unlocking"
        }
    }

    private var buttons: some View {
        VStack(spacing: 12) {
            if result != nil {
                PrimaryButton(title: "Done") {
                    close()
                }
            } else if session.isPaused || session.phase == .idle {
                PrimaryButton(title: session.completed == 0 ? "Start scanning" : "Resume scanning") {
                    session.start()
                }
            }
            if isAppTarget && result == nil && session.phase != .finished {
                Button("Open all apps instead") {
                    target = .allApps
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.steel)
                .padding(.top, 4)
            }
        }
    }

    private var isAppTarget: Bool {
        if case .app = target { return true }
        return false
    }

    // MARK: Actions

    private func finish() {
        result = model.completeUnlock(target)
    }

    private func close() {
        session.stop()
        if result == nil {
            model.cancelUnlock()
        } else {
            model.finishUnlock()
        }
    }
}
