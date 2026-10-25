import LocalAuthentication
import UIKit

enum Biometry: Equatable {
    case faceID
    case touchID
    case unavailable

    static func current() -> Biometry {
        let context = LAContext()
        var error: NSError?
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        default: return .unavailable
        }
    }

    var name: String { self == .touchID ? "Touch ID" : "Face ID" }
}

/// One scan per tap. Nothing chains on its own: after each scan the screen
/// waits for the button again. Every scan uses a fresh LAContext, so iOS
/// can't reuse the previous match.
@MainActor
final class ScanSession: ObservableObject {
    enum Phase: Equatable {
        /// Waiting for the person to tap Scan.
        case ready
        case scanning
        /// The last scan didn't count. Tapping Scan retries it.
        case failed(String)
        case finished
    }

    @Published private(set) var completed = 0
    @Published private(set) var phase: Phase = .ready
    @Published private(set) var usingPasscode = false

    let required: Int
    let method: String
    /// When on, any scan that doesn't pass sends the count back to zero.
    let restartOnFail: Bool
    var onFinish: (() -> Void)?

    private var context: LAContext?

    init(required: Int, method: String, restartOnFail: Bool) {
        self.required = max(1, required)
        self.method = method
        self.restartOnFail = restartOnFail
    }

    var nextScan: Int { min(completed + 1, required) }

    var canScan: Bool {
        phase != .scanning && phase != .finished
    }

    func scanOnce() {
        guard canScan else { return }
        phase = .scanning
        Task { [weak self] in
            await self?.runOne()
        }
    }

    func stop() {
        context?.invalidate()
    }

    private func runOne() async {
        let attempt = LAContext()
        attempt.localizedFallbackTitle = ""
        attempt.localizedCancelTitle = "Cancel"
        context = attempt
        defer { context = nil }
        guard let policy = choosePolicy(for: attempt) else { return }
        let number = nextScan
        do {
            let passed = try await attempt.evaluatePolicy(
                policy,
                localizedReason: "Scan \(number) of \(required) to unlock"
            )
            guard passed else {
                fail("That scan didn't count.", number: number)
                return
            }
            completed += 1
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            ActivityLog.add("Scan \(number) of \(required) passed\(usingPasscode ? " (passcode)" : "")")
            if completed >= required {
                phase = .finished
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onFinish?()
            } else {
                phase = .ready
            }
        } catch {
            let nsError = error as NSError
            // .appCancel is this screen closing, not a failed scan.
            if LAError.Code(rawValue: nsError.code) == .appCancel {
                phase = .failed(explain(nsError))
                return
            }
            fail(explain(nsError), number: number)
        }
    }

    private func fail(_ message: String, number: Int) {
        if restartOnFail && completed > 0 {
            completed = 0
            phase = .failed("\(message) Start over is on, so you're back to 0 of \(required).")
            ActivityLog.add("Scan \(number) of \(required) didn't count, so the count reset: \(message)")
        } else {
            phase = .failed(message)
            ActivityLog.add("Scan \(number) of \(required) didn't count: \(message)")
        }
    }

    /// Face ID only (no passcode button), unless Face ID can't be used at all,
    /// in which case the passcode counts as a scan so nobody gets stuck.
    private func choosePolicy(for attempt: LAContext) -> LAPolicy? {
        var error: NSError?
        if attempt.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            usingPasscode = false
            return .deviceOwnerAuthenticationWithBiometrics
        }
        let code = error.flatMap { LAError.Code(rawValue: $0.code) }
        let fallbackCodes: [LAError.Code] = [.biometryNotAvailable, .biometryNotEnrolled, .biometryLockout]
        if let code, fallbackCodes.contains(code) {
            var passcodeError: NSError?
            if attempt.canEvaluatePolicy(.deviceOwnerAuthentication, error: &passcodeError) {
                usingPasscode = true
                return .deviceOwnerAuthentication
            }
            phase = .failed(explain(passcodeError))
            return nil
        }
        phase = .failed(explain(error))
        return nil
    }

    private func explain(_ error: NSError?) -> String {
        guard let error else { return "\(method) isn't available right now." }
        guard let code = LAError.Code(rawValue: error.code) else { return error.localizedDescription }
        switch code {
        case .userCancel, .appCancel, .systemCancel:
            return "Scan cancelled. Your progress stays while this screen is open."
        case .authenticationFailed:
            return "\(method) didn't recognize you. Tap Scan to try again."
        case .biometryLockout:
            return "\(method) is locked after too many failed tries. Lock your iPhone, unlock it with your passcode, then come back."
        case .biometryNotEnrolled:
            return "Set up \(method) in Settings to unlock."
        case .biometryNotAvailable:
            return "\(method) is off for Super Screen Lock. Turn it on in Settings › Face ID & Passcode › Other Apps."
        case .passcodeNotSet:
            return "Set a passcode on this iPhone to unlock."
        default:
            return error.localizedDescription
        }
    }
}

/// One Face ID check that falls back to the passcode, for turning off delete protection.
enum OwnerCheck {
    @MainActor
    static func confirm(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return false }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }
}
