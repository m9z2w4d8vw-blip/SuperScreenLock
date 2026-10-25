import FamilyControls
import ManagedSettings
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var pickingAllowedApps = false
    @State private var showingDiagnostics = false

    var body: some View {
        ScrollView {
            // Re-renders every 30 seconds so "until 4:45 PM" states expire on screen.
            TimelineView(.periodic(from: .now, by: 30)) { _ in
                VStack(alignment: .leading, spacing: 0) {
                    Hero(symbol: heroSymbol, headline: headline, message: message)
                    Rule()
                        .padding(.top, 36)
                    if hasOpenApps {
                        openNow
                        Rule()
                    }
                    settings
                    actions
                    footer
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 44)
            }
        }
        .scrollIndicators(.hidden)
        .familyActivityPicker(isPresented: $pickingAllowedApps, selection: $model.allowedSelection)
        .sheet(isPresented: $showingDiagnostics) {
            DiagnosticsView()
                .environmentObject(model)
        }
    }

    // MARK: Hero

    private var hasOpenApps: Bool {
        !model.activeGrants.isEmpty || model.allAppsOpenUntil != nil
    }

    private var heroSymbol: String {
        if model.isShielding { return "lock.shield" }
        return model.saved.isEnabled ? "checkmark.shield" : "shield"
    }

    private var headline: String {
        if model.isShielding {
            if model.isLimitLocked { return "Apps are locked until midnight." }
            if let until = model.state.trialUntil { return "Test lock until \(Format.clock(until))." }
            return "Apps are locked."
        }
        if let until = model.allAppsOpenUntil {
            return "Everything's open until \(Format.clock(until))."
        }
        if model.saved.isEnabled {
            return "Apps lock after \(Format.duration(minutes: model.saved.dailyLimitMinutes)) today."
        }
        return "Apps will lock after \(Format.duration(minutes: model.draft.dailyLimitMinutes)) a day."
    }

    private var message: String {
        let scans = Format.scans(model.saved.requiredScans, method: model.biometryName)
        let window = Format.spokenDuration(minutes: model.saved.unlockMinutes)
        if model.isShielding {
            if model.isLimitLocked {
                let limit = Format.spokenDuration(minutes: model.saved.dailyLimitMinutes)
                return "You've used today's \(limit). Opening an app takes \(scans) and keeps it open for \(window). Super Screen Lock itself always stays open."
            }
            return "Every app is locked so you can try the unlock flow. Opening one takes \(scans)."
        }
        if let until = model.allAppsOpenUntil {
            return "You scanned in, so every app is open. Today's limit is still used up, so they lock again at \(Format.clock(until))."
        }
        if model.saved.isEnabled {
            let limit = Format.spokenDuration(minutes: model.saved.dailyLimitMinutes)
            let from = model.countingFromText
            let counting = from == "Midnight" ? "" : "Counting since \(from). "
            return "\(counting)Once today's screen time passes \(limit), every app locks until midnight. Opening one takes \(scans)."
        }
        let limit = Format.spokenDuration(minutes: model.draft.dailyLimitMinutes)
        let draftScans = Format.scans(model.draft.requiredScans, method: model.biometryName)
        return "Turn on the lock below and every app locks once today's screen time passes \(limit). Opening one then takes \(draftScans)."
    }

    // MARK: Open right now

    private var openNow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Open right now")
                .font(Theme.label)
                .foregroundStyle(Color.white)
            if let until = model.allAppsOpenUntil {
                HStack(spacing: 12) {
                    Text("All apps")
                        .font(Theme.label)
                        .foregroundStyle(Color.white)
                    Spacer(minLength: 8)
                    Text("until \(Format.clock(until))")
                        .font(Theme.small)
                        .foregroundStyle(Theme.mint)
                }
            }
            ForEach(model.activeGrants, id: \.token) { grant in
                HStack(spacing: 12) {
                    Label(grant.token)
                        .labelStyle(.titleAndIcon)
                        .font(Theme.label)
                        .foregroundStyle(Color.white)
                    Spacer(minLength: 8)
                    Text("until \(Format.clock(grant.until))")
                        .font(Theme.small)
                        .foregroundStyle(Theme.mint)
                }
            }
        }
        .padding(.vertical, 18)
    }

    // MARK: Settings

    private var settings: some View {
        VStack(alignment: .leading, spacing: 0) {
            CheckRow(
                title: "Lock apps after my daily limit",
                detail: lockDetail,
                isOn: model.saved.isEnabled
            ) {
                if model.saved.isEnabled {
                    model.turnOffTapped()
                } else {
                    model.turnOn()
                }
            }
            Rule()
            ValueRow(
                title: "Daily limit",
                detail: "All screen time counts toward it.",
                value: Format.duration(minutes: model.draft.dailyLimitMinutes),
                canDecrement: model.draft.dailyLimitMinutes > LockSettings.limitRange.lowerBound,
                canIncrement: model.draft.dailyLimitMinutes < LockSettings.limitRange.upperBound,
                decrement: { model.stepLimit(up: false) },
                increment: { model.stepLimit(up: true) }
            )
            Rule()
            ValueRow(
                title: "\(model.biometryName) scans",
                detail: "How many it takes to open a locked app.",
                value: "\(model.draft.requiredScans)",
                canDecrement: model.draft.requiredScans > LockSettings.scanRange.lowerBound,
                canIncrement: model.draft.requiredScans < LockSettings.scanRange.upperBound,
                decrement: { model.stepScans(up: false) },
                increment: { model.stepScans(up: true) }
            )
            Rule()
            ChoiceRow(
                title: "Each unlock lasts",
                options: LockSettings.unlockChoices.map { Choice(value: $0, label: Format.duration(minutes: $0)) },
                selection: $model.draft.unlockMinutes
            )
            Rule()
            ChoiceRow(
                title: "Scanning opens",
                detail: "If iOS can't tell which app you came from, scanning opens all apps.",
                options: [
                    Choice(value: UnlockScope.thatApp, label: "That app"),
                    Choice(value: UnlockScope.allApps, label: "All apps"),
                ],
                selection: $model.draft.unlockScope
            )
            Rule()
            allowedRow
            Rule()
        }
    }

    private var lockDetail: String {
        if !model.saved.isEnabled { return "Turning it on starts counting today's screen time." }
        if model.isLimitLocked { return "Today's limit is used up, so turning this off takes the same scans as unlocking." }
        return "Every app's screen time counts, every day."
    }

    private var allowedRow: some View {
        Button {
            pickingAllowedApps = true
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Always allowed")
                        .font(Theme.label)
                        .foregroundStyle(Color.white)
                    Text(allowedDetail)
                        .font(Theme.small)
                        .foregroundStyle(Theme.mint)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Text(allowedSummary)
                    .font(Theme.headline(30))
                    .foregroundStyle(Color.white)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.mint)
            }
            .padding(.vertical, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Always allowed, \(allowedSummary)")
        .accessibilityHint(allowedDetail)
    }

    private var allowedSummary: String {
        let count = model.allowedSelection.applicationTokens.count
        if count == 0 { return "None" }
        return count == 1 ? "1 app" : "\(count) apps"
    }

    private var allowedDetail: String {
        if model.allowedSelection.applicationTokens.count > 40 { return "Only the first 40 stay open." }
        if !model.allowedSelection.categoryTokens.isEmpty { return "Pick single apps. Categories are skipped." }
        return "These never lock."
    }

    // MARK: Actions and footer

    private var actions: some View {
        VStack(spacing: 12) {
            if model.hasUnsavedChanges {
                PrimaryButton(title: model.isLimitLocked ? "Scan to save changes" : "Save changes") {
                    model.saveTapped()
                }
            }
            if model.isShielding {
                SecondaryButton(title: "Open all apps for \(Format.duration(minutes: model.saved.unlockMinutes))") {
                    model.requestUnlockAll()
                }
            }
        }
        .padding(.top, 24)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.notifications == .denied {
                Text("Notifications are off, so tapping Unlock on a locked app can't bring you here. Open Super Screen Lock yourself, or turn notifications on in Settings.")
                    .font(Theme.small)
                    .foregroundStyle(Theme.mint)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("Why a notification? Apple's lock screen can't run \(model.biometryName), so tapping Unlock there sends a notification that brings you here to scan.")
                .font(Theme.small)
                .foregroundStyle(Theme.mint)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            TextLink(title: "Diagnostics and test lock") {
                showingDiagnostics = true
            }
        }
        .padding(.top, 16)
    }
}
