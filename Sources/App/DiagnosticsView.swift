import SwiftUI

struct DiagnosticsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [ActivityLog.Entry] = []
    @State private var activities: [String] = []

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
                    Rule()
                        .padding(.top, 32)
                    statusRow("Screen Time access", model.authorizationText)
                    Rule()
                    statusRow("Notifications", model.notificationText)
                    Rule()
                    statusRow("Lock", model.saved.isEnabled ? "On" : "Off")
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

    private func reload() {
        entries = ActivityLog.all()
        activities = model.scheduledActivities
    }
}
