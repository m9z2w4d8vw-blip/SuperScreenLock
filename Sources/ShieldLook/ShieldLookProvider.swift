import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Draws the screen that covers a locked app.
final class ShieldLookProvider: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        ShieldStash.remember(application)
        return ShieldDesign.make(name: application.localizedDisplayName)
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        ShieldStash.remember(application)
        return ShieldDesign.make(name: application.localizedDisplayName)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        ShieldDesign.make(name: webDomain.domain)
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        ShieldDesign.make(name: webDomain.domain)
    }
}

enum ShieldDesign {
    static func make(name: String?) -> ShieldConfiguration {
        let settings = SharedStore.settings
        let state = SharedStore.state
        let now = Date()
        let subject = name ?? "This app"
        let method = settings.biometryName
        let opens = settings.unlockScope == .allApps ? "all apps" : (name ?? "it")
        let window = Format.spokenDuration(minutes: settings.unlockMinutes)
        let howTo = "Scan \(method) \(Format.times(settings.requiredScans)) to open \(opens) for \(window)."

        let title: String
        let subtitle: String
        let button: String
        if !ShieldEngine.shouldLock(settings: settings, state: state, now: now) {
            title = "\(subject) is ready"
            subtitle = "Today's lock has ended."
            button = "Continue"
        } else if state.freshPending(at: now) != nil {
            title = "Check your notifications"
            subtitle = "Tap the Super Screen Lock banner to start your \(Format.scans(settings.requiredScans, method: method)). No banner? Open Super Screen Lock yourself."
            button = "Send it again"
        } else if settings.isEnabled && state.limitReached(on: now) {
            title = "\(subject) is locked"
            subtitle = "You've used today's \(Format.spokenDuration(minutes: settings.dailyLimitMinutes)). \(howTo)"
            button = "Unlock with \(method)"
        } else {
            title = "\(subject) is locked"
            subtitle = "This is a test lock. \(howTo)"
            button = "Unlock with \(method)"
        }

        return ShieldConfiguration(
            backgroundBlurStyle: .systemThickMaterialDark,
            backgroundColor: Palette.enamel.withAlphaComponent(0.94),
            icon: DialArt.image(ticks: min(max(settings.requiredScans, 1), 30)),
            title: ShieldConfiguration.Label(text: title, color: Palette.ivory),
            subtitle: ShieldConfiguration.Label(text: subtitle, color: Palette.steel),
            primaryButtonLabel: ShieldConfiguration.Label(text: button, color: Palette.enamel),
            primaryButtonBackgroundColor: Palette.brass,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Close", color: Palette.ivory)
        )
    }
}
