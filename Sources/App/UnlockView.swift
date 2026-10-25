import FamilyControls
import ManagedSettings
import SwiftUI

/// The scan screen: one checkbox per required scan, and one tap per scan.
/// For a single-app unlock with no app named yet, it asks which app first.
struct UnlockView: View {
    @EnvironmentObject private var model: AppModel
    @StateObject private var session: ScanSession
    @State private var result: String?
    @State private var picked = FamilyActivitySelection()
    @State private var choosingApps = false
    /// Apps shown in the grid: recent unlocks, then anything in Also lock.
    @State private var tiles: [ApplicationToken]
    @State private var selection: Set<ApplicationToken> = []
    private let target: UnlockRequest.Target
    private let note: String?

    init(request: UnlockRequest, requiredScans: Int, method: String, restartOnFail: Bool) {
        _session = StateObject(wrappedValue: ScanSession(required: requiredScans, method: method, restartOnFail: restartOnFail))
        _tiles = State(initialValue: Self.startingTiles())
        target = request.target
        note = request.note
    }

    private static func startingTiles() -> [ApplicationToken] {
        var tokens = RecentApps.all().map(\.token)
        for token in SharedStore.settings.extraLockedApps where !tokens.contains(token) {
            tokens.append(token)
        }
        return tokens
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
        .familyActivityPicker(isPresented: $choosingApps, selection: $picked)
        .onChange(of: choosingApps) { showing in
            // Apps picked in the system list join the grid, already selected.
            guard !showing else { return }
            let fresh = picked.applicationTokens
            for token in fresh where !tiles.contains(token) {
                tiles.insert(token, at: 0)
            }
            selection.formUnion(fresh)
        }
        .onAppear {
            session.onFinish = { finish() }
        }
        .onDisappear {
            session.stop()
        }
    }

    // MARK: Which apps

    /// Apps named by the request, or picked here when the request named none.
    private var presetApps: [ApplicationToken] {
        if case .apps(let tokens) = target { return tokens }
        return []
    }

    private var isAppsTarget: Bool {
        if case .apps = target { return true }
        return false
    }

    private var chosenApps: [ApplicationToken] {
        if !presetApps.isEmpty { return presetApps }
        return tiles.filter { selection.contains($0) }
    }

    private var needsChoice: Bool {
        isAppsTarget && chosenApps.isEmpty && result == nil
    }

    /// The grid stays up until the first scan, so the choice can still change.
    private var showsGrid: Bool {
        isAppsTarget && presetApps.isEmpty && result == nil && session.completed == 0 && session.phase != .scanning
    }

    /// What actually opens once every scan passes.
    private var finalTarget: UnlockRequest.Target {
        isAppsTarget ? .apps(chosenApps) : target
    }

    // MARK: Text

    private var glyph: String {
        if result != nil { return "checkmark.shield" }
        return model.biometryName == "Touch ID" ? "touchid" : "faceid"
    }

    private var headline: String {
        if result != nil {
            switch target {
            case .apps: return chosenApps.count > 1 ? "They're open." : "It's open."
            case .allApps: return "Everything's open."
            case .saveSettings: return "Changes saved."
            case .turnOff: return "The lock is off."
            case .allowAppDeletion: return "Deleting is back on."
            }
        }
        if needsChoice { return "Choose the app." }
        switch session.phase {
        case .ready:
            if session.completed == 0 {
                return session.required == 1 ? "1 scan to go." : "\(session.required) scans to go."
            }
            return "\(session.completed) of \(session.required) done."
        case .scanning:
            return "Scanning \(session.nextScan) of \(session.required)."
        case .failed:
            return session.completed == 0 && session.restartOnFail
                ? "Back to 0 of \(session.required)."
                : "Scan \(session.nextScan) didn't count."
        case .finished:
            return "All \(session.required) done."
        }
    }

    private var window: String {
        Format.spokenDuration(minutes: model.saved.unlockMinutes)
    }

    private var targetDescription: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch target {
            case .apps:
                if showsGrid {
                    Text(tiles.isEmpty
                         ? "Pick the app to open for \(window)."
                         : "Tap the app to open for \(window). You can pick more than one.")
                        .font(Theme.body)
                        .foregroundStyle(Theme.mint)
                        .fixedSize(horizontal: false, vertical: true)
                    appGrid
                        .padding(.top, 10)
                    if tiles.isEmpty {
                        Text("Apps you unlock show up here, so next time it's one tap.")
                            .font(Theme.small)
                            .foregroundStyle(Theme.mint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    ForEach(chosenApps, id: \.self) { token in
                        Label(token)
                            .labelStyle(.titleAndIcon)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.white)
                    }
                    Text(chosenApps.count > 1 ? "Open for \(window), then they lock again." : "Opens for \(window), then locks again.")
                        .font(Theme.body)
                        .foregroundStyle(Theme.mint)
                }
                if !picked.categoryTokens.isEmpty && picked.applicationTokens.isEmpty {
                    Text("Categories can't be opened on their own. Pick single apps.")
                        .font(Theme.small)
                        .foregroundStyle(Theme.mint)
                }
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
            case .allowAppDeletion:
                Text("Allowing app deletion")
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
        if needsChoice {
            return "Then scan \(model.biometryName) \(Format.times(session.required)), one tap each."
        }
        switch session.phase {
        case .ready:
            if session.completed == 0 {
                let restart = session.restartOnFail ? " A failed scan starts you over." : ""
                return "Each scan needs its own tap. Tap the button when you're ready.\(restart)"
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

    private var appGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
            ForEach(tiles, id: \.self) { token in
                AppTile(token: token, selected: selection.contains(token)) {
                    if selection.contains(token) {
                        selection.remove(token)
                    } else {
                        selection.insert(token)
                    }
                }
            }
            OtherAppTile {
                choosingApps = true
            }
        }
    }

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
                PrimaryButton(title: scanButtonTitle, enabled: session.canScan && !needsChoice) {
                    session.scanOnce()
                }
            }
        }
    }

    private var scanButtonTitle: String {
        if needsChoice { return "Pick an app first" }
        switch session.phase {
        case .scanning: return "Scanning…"
        case .failed: return session.completed == 0 && session.restartOnFail ? "Start over" : "Try scan \(session.nextScan) again"
        case .ready, .finished: return "Scan \(session.nextScan) of \(session.required)"
        }
    }

    // MARK: Actions

    private func finish() {
        result = model.completeUnlock(finalTarget)
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
