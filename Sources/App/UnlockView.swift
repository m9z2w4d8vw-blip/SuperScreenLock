import FamilyControls
import ManagedSettings
import SwiftUI

/// The scan screen: one checkbox per required scan, and one tap per scan.
struct UnlockView: View {
    @EnvironmentObject private var model: AppModel
    @StateObject private var session: ScanSession
    @State private var result: String?
    private let target: UnlockRequest.Target
    private let note: String?

    init(request: UnlockRequest, requiredScans: Int, method: String) {
        _session = StateObject(wrappedValue: ScanSession(required: requiredScans, method: method))
        target = request.target
        note = request.note
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
        .onAppear {
            session.onFinish = { finish() }
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
        case .ready:
            if session.completed == 0 {
                return session.required == 1 ? "1 scan to go." : "\(session.required) scans to go."
            }
            return "\(session.completed) of \(session.required) done."
        case .scanning:
            return "Scanning \(session.nextScan) of \(session.required)."
        case .failed:
            return "Scan \(session.nextScan) didn't count."
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
                Text("Opens for \(window), then locks again.")
                    .font(Theme.body)
                    .foregroundStyle(Theme.mint)
            case .allApps:
                Text("All apps")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.white)
                Text("Open for \(window), then everything locks again.")
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
            if let note {
                Text(note)
                    .font(Theme.small)
                    .foregroundStyle(Theme.mint)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
        }
    }

    private var statusLine: String {
        if let result { return result }
        switch session.phase {
        case .ready:
            if session.completed == 0 {
                return "Each scan needs its own tap. Tap the button when you're ready."
            }
            let left = session.required - session.completed
            return left == 1
                ? "One more. Tap the button for the last scan."
                : "\(left) to go. Tap the button for the next scan."
        case .scanning:
            if session.usingPasscode { return "Enter your passcode." }
            return model.biometryName == "Touch ID" ? "Rest your finger on Touch ID." : "Look at your iPhone."
        case .failed(let message):
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
            } else {
                PrimaryButton(title: scanButtonTitle, enabled: session.canScan) {
                    session.scanOnce()
                }
            }
        }
    }

    private var scanButtonTitle: String {
        switch session.phase {
        case .scanning: return "Scanning…"
        case .failed: return "Try scan \(session.nextScan) again"
        case .ready, .finished: return "Scan \(session.nextScan) of \(session.required)"
        }
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
