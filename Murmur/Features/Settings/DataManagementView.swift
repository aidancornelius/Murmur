//
//  DataManagementView.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 02/10/2025.
//

import SwiftUI
import UniformTypeIdentifiers
import CoreData

struct DataManagementView: View {
    @EnvironmentObject private var appearanceManager: AppearanceManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var showBackupSheet = false
    @State private var showRestoreSheet = false
    @State private var showResetConfirmation = false
    @State private var showFinalResetConfirmation = false
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private var palette: ColorPalette {
        appearanceManager.currentPalette(for: colorScheme)
    }

    var body: some View {
        Form {
            Section {
                Text("You may wish to back up your entries, for instance, to transfer them to a new device. You may also reset the app to start fresh.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }

            Section("Backup") {
                Button {
                    showBackupSheet = true
                } label: {
                    Label("Create backup", systemImage: "arrow.up.doc")
                }
                .disabled(isProcessing)

                Text("Create an encrypted backup of all your data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(palette.surfaceColor)

            Section("Restore") {
                Button {
                    showRestoreSheet = true
                } label: {
                    Label("Restore from backup", systemImage: "arrow.down.doc")
                }
                .disabled(isProcessing)

                Text("Replace all data with a backup file")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(palette.surfaceColor)

            Section("Reset") {
                Button(role: .destructive) {
                    showResetConfirmation = true
                } label: {
                    Label("Reset all data", systemImage: "trash")
                }
                .disabled(isProcessing)

                Text("Permanently delete all symptoms, entries, and settings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(palette.surfaceColor)

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .listRowBackground(palette.surfaceColor)
            }

            if let successMessage {
                Section {
                    Text(successMessage)
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                .listRowBackground(palette.surfaceColor)
            }
        }
        .navigationTitle("Data management")
        .themedScrollBackground()
        .sheet(isPresented: $showBackupSheet) {
            BackupView(isProcessing: $isProcessing, errorMessage: $errorMessage, successMessage: $successMessage)
        }
        .sheet(isPresented: $showRestoreSheet) {
            RestoreView(isProcessing: $isProcessing, errorMessage: $errorMessage, successMessage: $successMessage)
        }
        .alert("Reset all data?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Continue", role: .destructive) {
                showFinalResetConfirmation = true
            }
        } message: {
            Text("This will permanently delete all your symptom entries, tracked symptoms, and settings. This cannot be undone.")
        }
        .alert("Are you absolutely sure?", isPresented: $showFinalResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete everything", role: .destructive) {
                resetAllData()
            }
        } message: {
            Text("This is your last chance. All data will be permanently deleted.")
        }
    }

    private func resetAllData() {
        isProcessing = true
        errorMessage = nil
        successMessage = nil

        Task {
            do {
                await MainActor.run {
                    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                }

                let context = CoreDataStack.shared.newBackgroundContext()

                try await context.perform {
                    // Delete all symptom entries
                    let entryDeleteRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "SymptomEntry")
                    let entryDelete = NSBatchDeleteRequest(fetchRequest: entryDeleteRequest)
                    try context.execute(entryDelete)

                    // Delete all symptom types
                    let typeDeleteRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "SymptomType")
                    let typeDelete = NSBatchDeleteRequest(fetchRequest: typeDeleteRequest)
                    try context.execute(typeDelete)

                    // Delete all activity events
                    let activityDeleteRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "ActivityEvent")
                    let activityDelete = NSBatchDeleteRequest(fetchRequest: activityDeleteRequest)
                    try context.execute(activityDelete)

                    // Delete all manual cycle entries
                    let cycleDeleteRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "ManualCycleEntry")
                    let cycleDelete = NSBatchDeleteRequest(fetchRequest: cycleDeleteRequest)
                    try context.execute(cycleDelete)

                    // Delete all reminders
                    let reminderDeleteRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Reminder")
                    let reminderDelete = NSBatchDeleteRequest(fetchRequest: reminderDeleteRequest)
                    try context.execute(reminderDelete)

                    try context.save()
                }

                await MainActor.run {
                    HapticFeedback.success.trigger()
                    isProcessing = false
                    successMessage = "All data has been deleted"
                }
            } catch {
                await MainActor.run {
                    HapticFeedback.error.trigger()
                    isProcessing = false
                    errorMessage = "Failed to reset data: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Backup View

struct BackupView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isProcessing: Bool
    @Binding var errorMessage: String?
    @Binding var successMessage: String?

    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showShareSheet = false
    @State private var backupURL: URL?

    private let backupService = DataBackupService()

    var body: some View {
        NavigationStack {
            Form {
                Section("Backup password") {
                    SecureField("Enter password", text: $password)
                        .textContentType(.newPassword)
                        .autocorrectionDisabled()

                    SecureField("Confirm password", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .autocorrectionDisabled()

                    if !password.isEmpty && password.count < 8 {
                        Text("Password must be at least 8 characters")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else if !confirmPassword.isEmpty && password != confirmPassword {
                        Text("Passwords don't match")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else {
                        Text("You'll need this password to restore the backup")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button("Create backup") {
                        createBackup()
                    }
                    .disabled(!canCreateBackup || isProcessing)
                }
            }
            .themedScrollBackground()
            .navigationTitle("Create backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isProcessing)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let backupURL {
                    ShareSheet(items: [backupURL])
                        .onDisappear {
                            dismiss()
                        }
                }
            }
        }
        .themedSurface()
    }

    private var canCreateBackup: Bool {
        !password.isEmpty && password == confirmPassword && password.count >= 8
    }

    private func createBackup() {
        isProcessing = true
        errorMessage = nil
        successMessage = nil

        Task {
            do {
                let url = try await backupService.createBackup(password: password)
                await MainActor.run {
                    HapticFeedback.success.trigger()
                    backupURL = url
                    isProcessing = false
                    successMessage = "Backup created successfully"
                    showShareSheet = true
                }
            } catch {
                await MainActor.run {
                    HapticFeedback.error.trigger()
                    isProcessing = false
                    errorMessage = error.localizedDescription
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Restore View

struct RestoreView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isProcessing: Bool
    @Binding var errorMessage: String?
    @Binding var successMessage: String?

    @State private var password = ""
    @State private var showFilePicker = false
    @State private var selectedFileURL: URL?
    @State private var showConfirmation = false

    private let backupService = DataBackupService()

    var body: some View {
        NavigationStack {
            Form {
                Section("Backup file") {
                    if let url = selectedFileURL {
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundStyle(.blue)
                            Text(url.lastPathComponent)
                                .lineLimit(1)
                            Spacer()
                            Button("Change") {
                                showFilePicker = true
                            }
                            .buttonStyle(.borderless)
                        }
                    } else {
                        Button {
                            showFilePicker = true
                        } label: {
                            Label("Choose backup file", systemImage: "folder")
                        }
                    }
                }

                Section("Password") {
                    SecureField("Backup password", text: $password)
                        .textContentType(.password)
                        .autocorrectionDisabled()

                    Text("Enter the password you used to create the backup")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button("Restore backup") {
                        showConfirmation = true
                    }
                    .disabled(!canRestore || isProcessing)

                    Text("Warning: This will replace all your current data")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .themedScrollBackground()
            .navigationTitle("Restore backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isProcessing)
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [UTType(filenameExtension: "murmurbackup") ?? .data],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        selectedFileURL = url
                    }
                case .failure(let error):
                    errorMessage = "Failed to select file: \(error.localizedDescription)"
                }
            }
            .alert("Replace all data?", isPresented: $showConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Restore", role: .destructive) {
                    restoreBackup()
                }
            } message: {
                Text("This will delete all current data and replace it with the backup. This cannot be undone.")
            }
        }
        .themedSurface()
    }

    private var canRestore: Bool {
        selectedFileURL != nil && !password.isEmpty
    }

    private func restoreBackup() {
        guard let url = selectedFileURL else { return }

        isProcessing = true
        errorMessage = nil
        successMessage = nil

        Task {
            do {
                // Copy file to temp location if needed (for security scoped resources)
                let accessGranted = url.startAccessingSecurityScopedResource()
                defer {
                    if accessGranted {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                try await backupService.restoreBackup(from: url, password: password)

                await MainActor.run {
                    HapticFeedback.success.trigger()
                    isProcessing = false
                    successMessage = "Backup restored successfully"
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    HapticFeedback.error.trigger()
                    isProcessing = false
                    errorMessage = error.localizedDescription
                    dismiss()
                }
            }
        }
    }
}
