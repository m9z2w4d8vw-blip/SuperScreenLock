import FamilyControls
import ManagedSettings
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var pickingAllowedApps = false
    @State private var showingDiagnostics = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                dial
                if !model.activeGrants.isEmpty || model.allAppsOpenUntil != nil {
                    openNow
                }
                controls
                actions
            }
            .padding(.horizontal, 22)
            .padding(.top, 12)
            .padding(.bottom, 36)
        }
        .scrollIndicators(.hidden)
        .familyActivityPicker(isPresented: $pickingAllowedApps, selection: $model.allowedSelection)
        .sheet(isPresented: $showingDiagnostics) {
            DiagnosticsView()
                .environmentObject(model)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Super Screen Lock")
                    .font(Theme.display(26))
                    .foregroundStyle(Theme.ivory)
                Text("Every app locks once you hit your daily limit.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.steel)
            }
            Spacer(minLength: 12)
            Button {
                showingDiagnostics = true
            } label: {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.steel)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Diagnostics")
        }
    }

    // MARK: Dial

    private var dial: some View {
        TimelineView(.periodic(from: .now, by: 30)) { _ in
            VStack(spacing: 16) {
                ZStack {
                    DialView(
                        total: model.draft.requiredScans,
                        filled: dialFill,
                        dimmed: !model.saved.isEnabled && !model.isShielding
                    )
                    VStack(spacing: 4) {
                        Text(statusWord)
                            .font(Theme.display(34))
                            .foregroundStyle(Theme.ivory)
                        Text(statusDetail)
                            .font(.subheadline)
                            .foregroundStyle(Theme.steel)
                    }
                }
                .frame(width: 236, height: 236)
                .accessibilityElement(children: .combine)

                Text(statusExplanation)
                    .font(.callout)
                    .foregroundStyle(Theme.steel)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var dialFill: Int {
        model.saved.isEnabled && !model.isShielding ? model.draft.requiredScans : 0
    }

    private var statusWord: String {
        if model.isShielding { return "Locked" }
        if !model.saved.isEnabled { return "Off" }
        return "Open"
    }

    private var statusDetail: String {
        if model.isShielding {
            if model.isLimitLocked { return "until midnight" }
            if let until = model.state.trialUntil { return "test ends \(Format.clock(until))" }
            return ""
        }
        if let until = model.allAppsOpenUntil { return "until \(Format.clock(until))" }
        return "\(Format.duration(minutes: model.draft.dailyLimitMinutes)) a day"
    }

    private var statusExplanation: String {
        if model.isShielding {
            let scans = Format.scans(model.saved.requiredScans, method: model.biometryName)
            return "Opening any app takes \(scans). Super Screen Lock itself always stays open."
        }
        if !model.saved.isEnabled {
            let scans = Format.scans(model.draft.requiredScans, method: model.biometryName)
            return "Turn it on and every app locks after your daily limit. Opening one then takes \(scans)."
        }
        if model.allAppsOpenUntil != nil {
            return "Today's limit is used up. Everything locks again when this window ends."
        }
        let limit = Format.spokenDuration(minutes: model.saved.dailyLimitMinutes)
        let from = model.countingFromText
        if from == "Midnight" {
            return "Every app locks after \(limit) of screen time today."
        }
        return "Counting since \(from) today. Every app locks after \(limit)."
    }

    // MARK: Open right now

    private var openNow: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Open right now")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.steel)
                .padding(.top, 14)
                .padding(.bottom, 2)
            if let until = model.allAppsOpenUntil {
                PlateRow(title: "All apps") {
                    Text("until \(Format.clock(until))")
                        .font(.subheadline)
                        .foregroundStyle(Theme.steel)
                }
            }
            ForEach(model.activeGrants, id: \.token) { grant in
                HStack(spacing: 12) {
                    Label(grant.token)
                        .labelStyle(.titleAndIcon)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.ivory)
                    Spacer(minLength: 8)
                    Text("until \(Format.clock(grant.until))")
                        .font(.subheadline)
                        .foregroundStyle(Theme.steel)
                }
                .padding(.vertical, 12)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
        .background(Theme.plate, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: Controls

    private var controls: some View {
        VStack(spacing: 0) {
            PlateRow(title: "Daily limit", detail: "All screen time counts") {
                ValueStepper(
                    value: Format.duration(minutes: model.draft.dailyLimitMinutes),
                    label: "Daily limit",
                    canDecrement: model.draft.dailyLimitMinutes > LockSettings.limitRange.lowerBound,
                    canIncrement: model.draft.dailyLimitMinutes < LockSettings.limitRange.upperBound,
                    decrement: { model.stepLimit(up: false) },
                    increment: { model.stepLimit(up: true) }
                )
            }
            Hairline()
            PlateRow(title: "\(model.biometryName) scans", detail: "To open a locked app") {
                ValueStepper(
                    value: "\(model.draft.requiredScans)",
                    label: "\(model.biometryName) scans",
                    canDecrement: model.draft.requiredScans > LockSettings.scanRange.lowerBound,
                    canIncrement: model.draft.requiredScans < LockSettings.scanRange.upperBound,
                    decrement: { model.stepScans(up: false) },
                    increment: { model.stepScans(up: true) }
                )
            }
            Hairline()
            VStack(alignment: .leading, spacing: 10) {
                Text("Each unlock lasts")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.ivory)
                Picker("Each unlock lasts", selection: $model.draft.unlockMinutes) {
                    ForEach(LockSettings.unlockChoices, id: \.self) { minutes in
                        Text(Format.duration(minutes: minutes)).tag(minutes)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.vertical, 14)
            Hairline()
            VStack(alignment: .leading, spacing: 10) {
                Text("Scanning opens")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.ivory)
                Picker("Scanning opens", selection: $model.draft.unlockScope) {
                    Text("That app").tag(UnlockScope.thatApp)
                    Text("All apps").tag(UnlockScope.allApps)
                }
                .pickerStyle(.segmented)
            }
            .padding(.vertical, 14)
            Hairline()
            Button {
                pickingAllowedApps = true
            } label: {
                PlateRow(title: "Always allowed", detail: allowedDetail) {
                    HStack(spacing: 6) {
                        Text(allowedSummary)
                            .foregroundStyle(Theme.steel)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.steel)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .background(Theme.plate, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var allowedSummary: String {
        let count = model.allowedSelection.applicationTokens.count
        if count == 0 { return "None" }
        return count == 1 ? "1 app" : "\(count) apps"
    }

    private var allowedDetail: String {
        if model.allowedSelection.applicationTokens.count > 40 { return "Only the first 40 apps stay open" }
        if !model.allowedSelection.categoryTokens.isEmpty { return "Pick single apps; categories are skipped" }
        return "These never lock"
    }

    // MARK: Actions

    private var actions: some View {
        VStack(spacing: 12) {
            if !model.saved.isEnabled {
                PrimaryButton(title: "Turn on Super Screen Lock") {
                    model.turnOn()
                }
            } else {
                if model.hasUnsavedChanges {
                    PrimaryButton(title: model.isLimitLocked ? "Scan to save changes" : "Save changes") {
                        model.saveTapped()
                    }
                }
                if model.isShielding {
                    QuietButton(title: "Open all apps for \(Format.duration(minutes: model.saved.unlockMinutes))") {
                        model.requestUnlockAll()
                    }
                }
                QuietButton(title: model.isLimitLocked ? "Scan to turn off" : "Turn off") {
                    model.turnOffTapped()
                }
            }
            if model.notifications == .denied {
                Text("Notifications are off, so tapping Unlock on a locked app can't bring you here. Open Super Screen Lock yourself, or turn notifications on in Settings.")
                    .font(.footnote)
                    .foregroundStyle(Theme.steel)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
