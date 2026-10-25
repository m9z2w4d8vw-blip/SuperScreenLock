import Foundation
import ManagedSettings

/// What one finished round of scans opens.
enum UnlockScope: String, Codable, CaseIterable, Identifiable {
    case thatApp
    case allApps

    var id: String { rawValue }
}

/// Everything the person picks in the app. The extensions read it too.
struct LockSettings: Codable, Equatable {
    var isEnabled = false
    var dailyLimitMinutes = 120
    var requiredScans = 10
    var unlockMinutes = 15
    var unlockScope: UnlockScope = .thatApp
    var allowedApps: Set<ApplicationToken> = []
    var biometryName = "Face ID"

    static let scanRange = 1...50
    static let limitRange = 5...720
    static let unlockChoices = [15, 30, 45, 60]

    init() {}

    private enum CodingKeys: String, CodingKey {
        case isEnabled, dailyLimitMinutes, requiredScans, unlockMinutes, unlockScope, allowedApps, biometryName
    }

    // Lenient on purpose: a missing key falls back to its default instead of
    // throwing away every other setting.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = (try? c.decode(Bool.self, forKey: .isEnabled)) ?? false
        dailyLimitMinutes = (try? c.decode(Int.self, forKey: .dailyLimitMinutes)) ?? 120
        requiredScans = (try? c.decode(Int.self, forKey: .requiredScans)) ?? 10
        unlockMinutes = (try? c.decode(Int.self, forKey: .unlockMinutes)) ?? 15
        unlockScope = (try? c.decode(UnlockScope.self, forKey: .unlockScope)) ?? .thatApp
        allowedApps = (try? c.decode(Set<ApplicationToken>.self, forKey: .allowedApps)) ?? []
        biometryName = (try? c.decode(String.self, forKey: .biometryName)) ?? "Face ID"
    }
}

/// One app opened by a finished round of scans.
struct AppGrant: Codable, Equatable {
    var token: ApplicationToken
    var until: Date
}

/// Written by the shield's "Unlock" button, picked up by the app.
struct PendingUnlock: Codable, Equatable {
    enum Source: String, Codable {
        /// The shield said exactly which app was covered.
        case app
        /// The shield only knew the app's category (the usual case with "lock everything").
        case category
    }

    var source: Source
    var appToken: ApplicationToken?
    var createdAt: Date
}

/// Today's lock state, shared across processes.
struct LockState: Codable, Equatable {
    var limitReachedDay: String?
    var limitReachedAt: Date?
    var appGrants: [AppGrant] = []
    var allAppsUntil: Date?
    var trialUntil: Date?
    var monitoringStartedAt: Date?
    var countsPastActivity = false
    var rearmDay: String?
    var rearmCount = 0
    var pending: PendingUnlock?

    init() {}

    private enum CodingKeys: String, CodingKey {
        case limitReachedDay, limitReachedAt, appGrants, allAppsUntil, trialUntil
        case monitoringStartedAt, countsPastActivity, rearmDay, rearmCount, pending
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        limitReachedDay = try? c.decode(String.self, forKey: .limitReachedDay)
        limitReachedAt = try? c.decode(Date.self, forKey: .limitReachedAt)
        appGrants = (try? c.decode([AppGrant].self, forKey: .appGrants)) ?? []
        allAppsUntil = try? c.decode(Date.self, forKey: .allAppsUntil)
        trialUntil = try? c.decode(Date.self, forKey: .trialUntil)
        monitoringStartedAt = try? c.decode(Date.self, forKey: .monitoringStartedAt)
        countsPastActivity = (try? c.decode(Bool.self, forKey: .countsPastActivity)) ?? false
        rearmDay = try? c.decode(String.self, forKey: .rearmDay)
        rearmCount = (try? c.decode(Int.self, forKey: .rearmCount)) ?? 0
        pending = try? c.decode(PendingUnlock.self, forKey: .pending)
    }
}

extension LockState {
    /// How long a tap on the shield's Unlock button stays valid.
    static let pendingLifetime: TimeInterval = 10 * 60

    func limitReached(on date: Date) -> Bool {
        limitReachedDay == DayKey.string(for: date)
    }

    func trialActive(at date: Date) -> Bool {
        guard let trialUntil else { return false }
        return trialUntil > date
    }

    func allAppsOpen(at date: Date) -> Bool {
        guard let allAppsUntil else { return false }
        return allAppsUntil > date
    }

    func activeGrants(at date: Date) -> [AppGrant] {
        appGrants.filter { $0.until > date }
    }

    func freshPending(at date: Date) -> PendingUnlock? {
        guard let pending, date.timeIntervalSince(pending.createdAt) < Self.pendingLifetime else { return nil }
        return pending
    }

    /// Drops every unlock, test lock and request that has run out by `date`.
    mutating func prune(asOf date: Date) {
        appGrants.removeAll { $0.until <= date }
        if let until = allAppsUntil, until <= date { allAppsUntil = nil }
        if let until = trialUntil, until <= date { trialUntil = nil }
        if let request = pending, date.timeIntervalSince(request.createdAt) >= Self.pendingLifetime { pending = nil }
    }
}
