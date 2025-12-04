// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// DataManagementView.swift
// Created by Aidan Cornelius-Bell on 02/10/2025.
// Settings view for data backup, restore, and export.
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
    @State private var autoBackupEnabled = AutoBackupService.shared.isEnabled
    @State private var autoBackups: [AutoBackupService.BackupInfo] = []
    @State private var selectedBackup: AutoBackupService.BackupInfo?

    private var palette: ColorPalette {
        appearanceManager.currentPalette(for: colorScheme)
    }

    var body: some View {
        Form {
            introSection
            autoBackupSection
            availableBackupsSection
            manualBackupSection
            restoreSection
            resetSection
            statusSection
        }
        .navigationTitle("Data management")
        .themedScrollBackground()
        .task {
            loadAutoBackups()
        }
        .sheet(isPresented: $showBackupSheet) {
            BackupView(isProcessing: $isProcessing, errorMessage: $errorMessage, successMessage: $successMessage)
        }
        .sheet(isPresented: $showRestoreSheet) {
            RestoreView(isProcessing: $isProcessing, errorMessage: $errorMessage, successMessage: $successMessage)
        }
        .sheet(item: $selectedBackup) { backup in
            RestoreAutoBackupView(
                backup: backup,
                isProcessing: $isProcessing,
                errorMessage: $errorMessage,
                successMessage: $successMessage,
                onRestoreComplete: {
                    selectedBackup = nil
                    loadAutoBackups()
                }
            )
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

    private var introSection: some View {
        Section {
            Text("You may wish to back up your entries, for instance, to transfer them to a new device. Automatic incremental backups are also available so you can recover from accidental deletion or incorrect entries. You may also reset the app to start fresh.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .listRowBackground(Color.clear)
        }
    }

    private var autoBackupSection: some View {
        Section {
            autoBackupToggle
            lastBackupRow
        } header: {
            Text("Auto backup")
        } footer: {
            Text("Automatic backups are stored securely on this device and are protected with encryption.")
                .font(.caption)
        }
        .listRowBackground(palette.surfaceColor)
    }

    private var autoBackupToggle: some View {
        Toggle(isOn: $autoBackupEnabled) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Auto backup")
                Text("Daily backups kept for 5 days, monthly for 3 months")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: autoBackupEnabled) { _, newValue in
            handleAutoBackupToggle(newValue)
        }
    }

    @ViewBuilder
    private var lastBackupRow: some View {
        if let lastBackup = AutoBackupService.shared.lastBackupDate {
            HStack {
                Text("Last backup")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(lastBackup, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var availableBackupsSection: some View {
        if !autoBackups.isEmpty {
            Section("Available auto backups") {
                ForEach(autoBackups) { backup in
                    backupRow(backup)
                }
            }
            .listRowBackground(palette.surfaceColor)
        }
    }

    private func backupRow(_ backup: AutoBackupService.BackupInfo) -> some View {
        Button {
            selectedBackup = backup
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(backup.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Text(backup.date, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .disabled(isProcessing)
    }

    private var manualBackupSection: some View {
        Section("Manual backup") {
            Button {
                showBackupSheet = true
            } label: {
                Label("Create backup", systemImage: "arrow.up.doc")
            }
            .disabled(isProcessing)

            Text("Create an encrypted backup to share or store externally")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .listRowBackground(palette.surfaceColor)
    }

    private var restoreSection: some View {
        Section("Restore") {
            Button {
                showRestoreSheet = true
            } label: {
                Label("Restore from file", systemImage: "arrow.down.doc")
            }
            .disabled(isProcessing)

            Text("Replace all data with a backup file")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .listRowBackground(palette.surfaceColor)
    }

    private var resetSection: some View {
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
    }

    @ViewBuilder
    private var statusSection: some View {
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

    private func handleAutoBackupToggle(_ enabled: Bool) {
        AutoBackupService.shared.isEnabled = enabled
        if enabled {
            // Create initial backup when enabled
            Task {
                do {
                    try await AutoBackupService.shared.performBackup()
                    loadAutoBackups()
                    successMessage = "Auto backup enabled and initial backup created"
                } catch {
                    errorMessage = "Auto backup enabled but initial backup failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func loadAutoBackups() {
        do {
            autoBackups = try AutoBackupService.shared.listBackups()
        } catch {
            errorMessage = "Failed to load backups: \(error.localizedDescription)"
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
                let viewContext = CoreDataStack.shared.context

                try await context.perform {
                    // Helper to perform batch delete and return deleted object IDs
                    func deleteAll(entityName: String) throws -> [NSManagedObjectID] {
                        let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                        let delete = NSBatchDeleteRequest(fetchRequest: request)
                        delete.resultType = .resultTypeObjectIDs
                        let result = try context.execute(delete) as? NSBatchDeleteResult
                        return (result?.result as? [NSManagedObjectID]) ?? []
                    }

                    // Delete all data and collect object IDs
                    let deletedObjectIDs: [NSManagedObjectID] = try [
                        deleteAll(entityName: "SymptomEntry"),
                        deleteAll(entityName: "SymptomType"),
                        deleteAll(entityName: "ActivityEvent"),
                        deleteAll(entityName: "SleepEvent"),
                        deleteAll(entityName: "MealEvent"),
                        deleteAll(entityName: "ManualCycleEntry"),
                        deleteAll(entityName: "Reminder")
                    ].flatMap { $0 }

                    // Merge the deletions into the view context
                    let changes = [NSDeletedObjectsKey: deletedObjectIDs]
                    NSManagedObjectContext.mergeChanges(
                        fromRemoteContextSave: changes,
                        into: [viewContext]
                    )

                    try context.save()
                }

                // Refresh view context to trigger UI updates
                await MainActor.run {
                    viewContext.refreshAllObjects()
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
    @FocusState private var focusedField: Field?

    private let backupService = DataBackupService()

    private enum Field {
        case password, confirmPassword
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Backup password") {
                    SecureField("Enter password", text: $password)
                        .textContentType(.newPassword)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .password)

                    SecureField("Confirm password", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .confirmPassword)

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
            .onAppear {
                focusedField = .password
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

                    Text("Warning: This will overwrite all your existing data with the data saved in this snapshot. This may not include your most recent additions.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .themedScrollBackground()
            .navigationTitle("Backup details")
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

// MARK: - Restore Auto Backup View

struct RestoreAutoBackupView: View {
    @Environment(\.dismiss) private var dismiss
    let backup: AutoBackupService.BackupInfo
    @Binding var isProcessing: Bool
    @Binding var errorMessage: String?
    @Binding var successMessage: String?
    let onRestoreComplete: () -> Void

    @State private var backupMetadata: DataBackupService.BackupMetadata?
    @State private var isLoadingMetadata = true
    @State private var metadataError: String?
    @State private var showConfirmation = false

    private let autoBackupService = AutoBackupService.shared

    init(backup: AutoBackupService.BackupInfo, isProcessing: Binding<Bool>, errorMessage: Binding<String?>, successMessage: Binding<String?>, onRestoreComplete: @escaping () -> Void) {
        self.backup = backup
        self._isProcessing = isProcessing
        self._errorMessage = errorMessage
        self._successMessage = successMessage
        self.onRestoreComplete = onRestoreComplete
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if isLoadingMetadata {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading backup information...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else if let error = metadataError {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else if let metadata = backupMetadata {
                    Form {
                        Section("Backup information") {
                            LabeledContent("Created", value: metadata.formattedCreatedAt)
                            LabeledContent("Type", value: backup.displayName)
                        }

                        Section("Contents") {
                            Text(metadata.summary)
                                .font(.subheadline)
                        }

                        Section {
                            Button("Restore this backup") {
                                showConfirmation = true
                            }
                            .disabled(isProcessing)

                            Text("Warning: This will replace all your current data")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    .themedScrollBackground()
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Unable to load backup information")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
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
            .task {
                await loadMetadata()
            }
            .alert("Replace all data?", isPresented: $showConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Restore", role: .destructive) {
                    restoreBackup()
                }
            } message: {
                if let metadata = backupMetadata {
                    Text("This will delete all current data and replace it with the backup from \(metadata.formattedCreatedAt) containing \(metadata.summary). This cannot be undone.")
                }
            }
        }
        .themedSurface()
    }

    private func loadMetadata() async {
        do {
            let password = try autoBackupService.retrievePasswordFromKeychain()
            let metadata = try await DataBackupService().readBackupMetadata(from: backup.url, password: password)
            await MainActor.run {
                backupMetadata = metadata
                isLoadingMetadata = false
            }
        } catch {
            await MainActor.run {
                metadataError = "Failed to read backup: \(error.localizedDescription)"
                isLoadingMetadata = false
            }
        }
    }

    private func restoreBackup() {
        isProcessing = true
        errorMessage = nil
        successMessage = nil

        Task {
            do {
                try await autoBackupService.restoreBackup(from: backup)

                await MainActor.run {
                    HapticFeedback.success.trigger()
                    isProcessing = false
                    successMessage = "Backup restored successfully"
                    onRestoreComplete()
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

