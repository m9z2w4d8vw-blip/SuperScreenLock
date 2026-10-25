import DeviceActivity
import SwiftUI

extension DeviceActivityReport.Context {
    /// Must match the context in the ActivityReport extension.
    static let totalActivity = Self("Total Activity")
}

/// Today's screen time, drawn by the ActivityReport extension.
struct ScreenTimeToday: View {
    @State private var filter = ScreenTimeToday.todayFilter()

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("On screen today")
                .font(Theme.label)
                .foregroundStyle(Color.white)
            DeviceActivityReport(.totalActivity, filter: filter)
                .frame(maxWidth: .infinity, minHeight: 64, maxHeight: 64, alignment: .leading)
        }
    }

    private static func todayFilter() -> DeviceActivityFilter {
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? Date()
        return DeviceActivityFilter(
            segment: .daily(during: DateInterval(start: start, end: end)),
            users: .all,
            devices: .init([.iPhone])
        )
    }
}
