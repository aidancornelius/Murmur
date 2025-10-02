import LocalAuthentication
import SwiftUI

/// Controls optional biometric or passcode lock that protects the app on foreground events.
@MainActor
final class AppLockController: ObservableObject {
    @AppStorage("appLockEnabled") private(set) var isEnabled: Bool = false
    @Published private(set) var isLockActive = false
    private var isAuthenticating = false

    var isLockEnabled: Bool { isEnabled }


    func setLockEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if !enabled {
            isLockActive = false
        }
    }

    func requestUnlockIfNeeded() async {
        guard isEnabled else {
            isLockActive = false
            return
        }
        guard isLockActive else { return }
        guard !isAuthenticating else { return }

        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            isAuthenticating = true
            let reason = "Unlock Murmur"
            do {
                try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
                isLockActive = false
            } catch {
                isLockActive = true
            }
            isAuthenticating = false
        } else {
            // No biometric available, keep disabled
            setLockEnabled(false)
        }
    }

    func appDidEnterBackground() {
        guard isEnabled else { return }
        isLockActive = true
    }
}
