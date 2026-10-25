import SwiftUI
import UIKit

struct DiagnosticsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [ActivityLog.Entry] = []
    @State private var activities: [String] = []
    @State private var exportURL: URL?
    @State private var copied = false

    var body: some View {
        ZStack {
            Theme.green.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Button("Done") {
                            dismiss()
                        }
                        .font(Theme.label)
                        .foregroundStyle(Color.white)
                        Spacer()
                        Button("Clear log") {
                            ActivityLog.clear()
                            reload()
                        }
                        .font(Theme.label)
                        .foregroundStyle(Theme.mint)
                    }
                    .padding(.bottom, 28)

                    Hero(
                        symbol: "waveform.path.ecg",
                        headline: "What's happening.",
                        message: "Status from the app and its three extensions. If something isn't locking, the log usually says why."
                    )
                    shareButton
                        .padding(.top, 28)
                    Rule()
                        .padding(.top, 32)
                    statusRow("Screen Time access", model.authorizationText)
                    Rule()
                    statusRow("Notifications", model.notificationText)
                    Rule()
                    statusRow("Lock", model.saved.isEnabled ? "On" : "Off")
                    Rule()
                    statusRow("Each unlock lasts", Format.spokenDuration(minutes: model.saved.unlockMinutes))
                    Rule()
                    statusRow("Monitor last ran", Heartbeat.last(Heartbeat.monitor).map(Format.clock) ?? "Never")
                    Rule()
                    statusRow("Today's limit reached", model.isLimitLocked ? "Yes" : "No")
                    Rule()
                    statusRow("Counting today from", model.countingFromText)
                    Rule()
                    statusRow("Scheduled", activities.isEmpty ? "Nothing" : activities.joined(separator: "\n"))
                    Rule()
                    CheckRow(
                        title: "Test lock",
                        detail: "Locks every app right now so you can try the unlock flow without waiting for your limit. It ends by itself after 15 minutes.",
                        isOn: model.isTrialRunning
                    ) {
                        if model.isTrialRunning {
                            model.endTrial()
                            reload()
                        } else {
                            model.startTrial()
                            dismiss()
                        }
                    }
                    Rule()

                    Text("Activity")
                        .font(Theme.label)
                        .foregroundStyle(Color.white)
                        .padding(.top, 24)
                        .padding(.bottom, 6)
                    if entries.isEmpty {
                        Text("Nothing logged yet.")
                            .font(Theme.small)
                            .foregroundStyle(Theme.mint)
                    }
                    ForEach(entries.reversed()) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.text)
                                .font(Theme.small)
                                .foregroundStyle(Color.white)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("\(entry.source), \(entry.at.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(Theme.mint)
                        }
                        .padding(.vertical, 10)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            reload()
        }
    }

    private func statusRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(Theme.label)
                .foregroundStyle(Color.white)
            Spacer(minLength: 12)
            Text(value)
                .font(Theme.body)
                .foregroundStyle(Theme.mint)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 16)
        .accessibilityElement(children: .combine)
    }

    /// The .txt is rebuilt every time this screen loads, so it's current when shared.
    @ViewBuilder
    private var shareButton: some View {
        if let exportURL {
            VStack(alignment: .leading, spacing: 10) {
                PrimaryButton(title: "Share debug log (.txt)") {
                    // Rebuilt on tap so the file includes everything up to now.
                    if let fresh = DebugReport.write(model: model) {
                        self.exportURL = fresh
                        SharePresenter.share(fresh)
                    }
                }
                SecondaryButton(title: copied ? "Copied" : "Copy debug log") {
                    let fresh = DebugReport.write(model: model) ?? exportURL
                    UIPasteboard.general.string = (try? String(contentsOf: fresh, encoding: .utf8)) ?? ""
                    copied = true
                }
                Text("A status snapshot plus everything logged by the app and its extensions. Share sends the .txt file, Copy puts the same text on the clipboard, and the latest copy is always in Files › On My iPhone › Super Screen Lock.")
                    .font(Theme.small)
                    .foregroundStyle(Theme.mint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func reload() {
        entries = ActivityLog.all()
        activities = model.scheduledActivities
        exportURL = DebugReport.write(model: model)
        copied = false
    }
}

/// UIKit's share sheet. Given a file URL it shares the file itself, where
/// SwiftUI's ShareLink sent some destinations only a link to it.
@MainActor
enum SharePresenter {
    static func share(_ url: URL) {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
        let window = windows.first(where: { $0.isKeyWindow }) ?? windows.first
        guard var top = window?.rootViewController else { return }
        while let presented = top.presentedViewController {
            top = presented
        }
        let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        sheet.popoverPresentationController?.sourceView = top.view
        top.present(sheet, animated: true)
    }
}
