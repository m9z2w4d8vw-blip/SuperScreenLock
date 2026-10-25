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

/// Runs the scans back to back. Every scan uses a fresh LAContext, so iOS
/// can't reuse the previous match and each one is a real scan.
@MainActor
final class ScanSession: ObservableObject {
    enum Phase: Equatable {
        case idle
        case scanning
        case paused(String)
        case finished
    }

    @Published private(set) var completed = 0
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var usingPasscode = false

    let required: Int
    let method: String
    var onFinish: (() -> Void)?

    private var task: Task<Void, Never>?
    private var context: LAContext?

    init(required: Int, method: String) {
        self.required = max(1, required)
        self.method = method
    }

    var isPaused: Bool {
        if case .paused = phase { return true }
        return false
    }

    func start() {
        guard task == nil, phase != .finished else { return }
        task = Task { [weak self] in
            await self?.run()
        }
    }

    func stop() {
        task?.cancel()
        context?.invalidate()
    }

    private func run() async {
        defer {
            task = nil
            context = nil
        }
        let tick = UIImpactFeedbackGenerator(style: .rigid)
        tick.prepare()

        while completed < required {
            if Task.isCancelled {
                phase = .paused("Scanning stopped.")
                return
            }
            phase = .scanning
            let attempt = LAContext()
            attempt.localizedFallbackTitle = ""
            attempt.localizedCancelTitle = "Stop"
            context = attempt
            guard let policy = choosePolicy(for: attempt) else { return }
            do {
                let passed = try await attempt.evaluatePolicy(
                    policy,
                    localizedReason: "Scan \(completed + 1) of \(required) to unlock"
                )
                guard passed else {
                    phase = .paused("That scan didn't count. Try it again.")
                    return
                }
                completed += 1
                tick.impactOccurred()
                tick.prepare()
            } catch {
                phase = .paused(explain(error as NSError))
                return
            }
            if completed < required {
                try? await Task.sleep(nanoseconds: 450_000_000)
            }
        }

        phase = .finished
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onFinish?()
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
            phase = .paused(explain(passcodeError))
            return nil
        }
        phase = .paused(explain(error))
        return nil
    }

    private func explain(_ error: NSError?) -> String {
        guard let error else { return "\(method) isn't available right now." }
        guard let code = LAError.Code(rawValue: error.code) else { return error.localizedDescription }
        switch code {
        case .userCancel, .appCancel, .systemCancel:
            return "Scanning paused. Your progress stays while this screen is open."
        case .authenticationFailed:
            return "\(method) didn't recognize you. Try that scan again."
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
