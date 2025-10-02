import LocalAuthentication
import SwiftUI

struct SecuritySettingsView: View {
    @EnvironmentObject private var appLock: AppLockController
    @State private var biometricsAvailable = false
    @State private var biometricTypeDescription = ""

    var body: some View {
        Form {
            Section("App lock") {
                Toggle(isOn: Binding(
                    get: { appLock.isLockEnabled },
                    set: { newValue in
                        if newValue {
                            biometricsAvailable ? appLock.setLockEnabled(true) : requestBiometrics()
                        } else {
                            appLock.setLockEnabled(false)
                        }
                    }
                )) {
                    VStack(alignment: .leading) {
                        Text("Lock Murmur when I close it")
                        if !biometricTypeDescription.isEmpty {
                            Text(biometricTypeDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Status") {
                Label(appLock.isLockEnabled ? "On" : "Off", systemImage: appLock.isLockEnabled ? "lock.fill" : "lock.open")
                    .foregroundStyle(appLock.isLockEnabled ? .green : .secondary)
            }
        }
        .navigationTitle("Privacy & security")
        .onAppear(perform: loadBiometricStatus)
    }

    private func loadBiometricStatus() {
        let context = LAContext()
        var error: NSError?
        biometricsAvailable = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
        if biometricsAvailable {
            switch context.biometryType {
            case .faceID:
                biometricTypeDescription = "Face ID"
            case .touchID:
                biometricTypeDescription = "Touch ID"
            case .opticID:
                biometricTypeDescription = "Optic ID"
            default:
                biometricTypeDescription = "Passcode"
            }
        } else {
            biometricTypeDescription = "Biometrics unavailable"
        }
    }

    private func requestBiometrics() {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        Task {
            do {
                try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Enable biometric lock")
                appLock.setLockEnabled(true)
                loadBiometricStatus()
            } catch {
                appLock.setLockEnabled(false)
            }
        }
    }
}
