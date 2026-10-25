import FamilyControls
import ManagedSettings
import SwiftUI

/// The scan screen: one checkbox per required scan, checked off as each one passes.
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
            Theme.green.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Button(result == nil ? "Cancel" : "Done") {
                        close()
                    }
                    .font(Theme.label)
                    .foregroundStyle(Color.white)
                    .padding(.bottom, 28)

                    HeaderGlyph(symbol: glyph)
                    Text(headline)
                        .font(Theme.headline(62))
                        .foregroundStyle(Color.white)
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.2), value: session.completed)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 18)
                        .accessibilityAddTraits(.isHeader)
                    targetDescription
                        .padding(.top, 14)

                    Rule()
                        .padding(.top, 32)
                    progressGrid
                        .padding(.vertical, 24)
                    Rule()

                    Text(statusLine)
                        .font(Theme.body)
                        .foregroundStyle(Theme.mint)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 20)
                    buttons
                        .padding(.top, 28)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
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

    // MARK: Text

    private var glyph: String {
        if result != nil { return "checkmark.shield" }
        return model.biometryName == "Touch ID" ? "touchid" : "faceid"
    }

    private var headline: String {
        if result != nil {
            switch target {
            case .app: return "It's open."
            case .allApps: return "Everything's open."
            case .saveSettings: return "Changes saved."
            case .turnOff: return "The lock is off."
            }
        }
        switch session.phase {
        case .idle:
            return "Get ready to scan."
        case .scanning:
            return "Scan \(min(session.completed + 1, session.required)) of \(session.required)."
        case .paused:
            return "Paused at \(session.completed) of \(session.required)."
        case .finished:
            return "All \(session.required) done."
        }
    }

    private var window: String {
        Format.spokenDuration(minutes: model.saved.unlockMinutes)
    }

    private var targetDescription: some View {
        VStack(alignment: .leading, spacing: 6) {
            switch target {
            case .app(let token):
                Label(token)
                    .labelStyle(.titleAndIcon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.white)
                Text("Opens for \(window).")
                    .font(Theme.body)
                    .foregroundStyle(Theme.mint)
            case .allApps:
                Text("All apps")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.white)
                Text("Open for \(window).")
                    .font(Theme.body)
                    .foregroundStyle(Theme.mint)
            case .saveSettings:
                Text("Saving your changes")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.white)
                Text("Today's limit is used up, so saving takes the same scans as unlocking.")
                    .font(Theme.body)
                    .foregroundStyle(Theme.mint)
                    .fixedSize(horizontal: false, vertical: true)
            case .turnOff:
                Text("Turning off the lock")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.white)
                Text("Today's limit is used up, so this takes the same scans as unlocking.")
                    .font(Theme.body)
                    .foregroundStyle(Theme.mint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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
                ? "Enter your passcode for scan \(next)."
                : "Each box checks off when a scan passes."
        case .paused(let message):
            return message
        case .finished:
            return "Unlocking."
        }
    }

    // MARK: Pieces

    private var progressGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.fixed(24), spacing: 9), count: 10),
            alignment: .leading,
            spacing: 9
        ) {
            ForEach(0..<session.required, id: \.self) { index in
                Checkbox(isOn: index < session.completed, size: 24)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(session.completed) of \(session.required) scans done")
    }

    private var buttons: some View {
        VStack(alignment: .leading, spacing: 14) {
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
                TextLink(title: "Open all apps instead") {
                    target = .allApps
                }
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
