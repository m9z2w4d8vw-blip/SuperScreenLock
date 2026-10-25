import SwiftUI

struct DiagnosticsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [ActivityLog.Entry] = []
    @State private var activities: [String] = []

    var body: some View {
        NavigationStack {
            List {
                Section("Status") {
                    LabeledContent("Screen Time access", value: model.authorizationText)
                    LabeledContent("Notifications", value: model.notificationText)
                    LabeledContent("Lock", value: model.saved.isEnabled ? "On" : "Off")
                    LabeledContent("Today's limit reached", value: model.isLimitLocked ? "Yes" : "No")
                    LabeledContent("Counting today from", value: model.countingFromText)
                    LabeledContent("Scheduled", value: activities.isEmpty ? "Nothing" : activities.joined(separator: "\n"))
                }
                .listRowBackground(Theme.plate)

                Section {
                    if model.isTrialRunning {
                        Button("End the test lock") {
                            model.endTrial()
                            reload()
                        }
                    } else {
                        Button("Test the lock for 15 minutes") {
                            model.startTrial()
                            dismiss()
                        }
                    }
                } footer: {
                    Text("Locks every app right away so you can try the whole unlock flow without waiting for your limit. It ends by itself after 15 minutes.")
                }
                .listRowBackground(Theme.plate)

                Section("Activity") {
                    if entries.isEmpty {
                        Text("Nothing logged yet.")
                            .foregroundStyle(Theme.steel)
                    }
                    ForEach(entries.reversed()) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.text)
                                .foregroundStyle(Theme.ivory)
                            Text("\(entry.source), \(entry.at.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(Theme.steel)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .listRowBackground(Theme.plate)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.enamel.ignoresSafeArea())
            .navigationTitle("Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear log") {
                        ActivityLog.clear()
                        reload()
                    }
                }
            }
            .onAppear {
                reload()
            }
        }
    }

    private func reload() {
        entries = ActivityLog.all()
        activities = model.scheduledActivities
    }
}
