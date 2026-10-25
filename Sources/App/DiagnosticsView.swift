import SwiftUI

struct DiagnosticsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [ActivityLog.Entry] = []
    @State private var activities: [String] = []
    @State private var exportURL: URL?

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
                ShareLink(item: exportURL, preview: SharePreview("Super Screen Lock debug log")) {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Share debug log (.txt)")
                            .font(Theme.label)
                    }
                    .foregroundStyle(Theme.green)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.white)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Text("A status snapshot plus everything logged by the app and all three extensions. Save it to Files or send it over.")
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
    }
}
