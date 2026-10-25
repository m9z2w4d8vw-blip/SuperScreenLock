import DeviceActivity
import SwiftUI

/// iOS only hands usage numbers to this extension. It draws the screen-time
/// figure inside the app's home screen; the app itself never sees the number.
@main
struct ActivityReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        TotalActivityReport { total in
            TotalActivityView(total: total)
        }
    }
}

extension DeviceActivityReport.Context {
    /// Must match the context the app asks for.
    static let totalActivity = Self("Total Activity")
}

/// Adds up every activity segment in the app's filter: today, on this iPhone.
struct TotalActivityReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .totalActivity
    let content: (String) -> TotalActivityView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> String {
        let total = await data
            .flatMap { $0.activitySegments }
            .reduce(TimeInterval(0)) { $0 + $1.totalActivityDuration }
        let minutes = Int(total / 60)
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 { return "\(rest)m" }
        return rest == 0 ? "\(hours)h" : "\(hours)h \(rest)m"
    }
}

/// Same green, white and DIN Condensed as the app.
struct TotalActivityView: View {
    let total: String

    var body: some View {
        Text(total)
            .font(.custom("DINCondensed-Bold", size: 54, relativeTo: .largeTitle))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(Color(red: 23.0 / 255, green: 112.0 / 255, blue: 75.0 / 255))
            .accessibilityLabel("\(total) of screen time today")
    }
}
