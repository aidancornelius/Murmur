//
//  ReminderFormView.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 02/10/2025.
//

import SwiftUI

struct ReminderFormView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    let editingReminder: Reminder?
    @State private var time: Date = Date()
    @State private var repeatsOn: Set<Weekday> = []
    @State private var isEnabled = true
    @State private var errorMessage: String?

    private let calendar = Calendar.current

    init(editingReminder: Reminder?) {
        self.editingReminder = editingReminder
        if let reminder = editingReminder {
            let components = DateComponents(hour: Int(reminder.hour), minute: Int(reminder.minute))
            _time = State(initialValue: Calendar.current.date(from: components) ?? Date())
            if let stored = reminder.repeatsOn as? [String] {
                _repeatsOn = State(initialValue: Set(stored.compactMap(Weekday.init(rawValue:))))
            }
            _isEnabled = State(initialValue: reminder.isEnabled)
        }
    }

    var body: some View {
        Form {
            DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)

            Section("Repeat on") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)) {
                    ForEach(Weekday.allCases) { day in
                        Text(day.shortTitle)
                            .frame(maxWidth: .infinity)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(repeatsOn.contains(day) ? Color.accentColor.opacity(0.2) : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(repeatsOn.contains(day) ? Color.accentColor : Color.gray.opacity(0.2))
                            )
                            .onTapGesture {
                                HapticFeedback.selection.trigger()
                                if repeatsOn.contains(day) {
                                    repeatsOn.remove(day)
                                } else {
                                    repeatsOn.insert(day)
                                }
                            }
                    }
                }
            }

            Toggle("On", isOn: $isEnabled)
                .onChange(of: isEnabled) { _, _ in
                    HapticFeedback.selection.trigger()
                }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(editingReminder == nil ? "Add a reminder" : "Update reminder")
        .themedScrollBackground()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", role: .cancel) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
            }
        }
    }

    private func save() {
        let components = calendar.dateComponents([.hour, .minute], from: time)
        guard let hour = components.hour, let minute = components.minute else {
            errorMessage = "Please choose a valid time."
            return
        }

        let reminder = editingReminder ?? Reminder(context: context)
        if editingReminder == nil { reminder.id = UUID() }
        reminder.hour = Int16(hour)
        reminder.minute = Int16(minute)
        reminder.repeatsOn = repeatsOn.map(\.rawValue) as NSArray
        reminder.isEnabled = isEnabled

        do {
            try context.save()
            HapticFeedback.success.trigger()
            Task {
                if reminder.isEnabled {
                    _ = try? await NotificationScheduler.requestAuthorization()
                    try? await NotificationScheduler.schedule(reminder: reminder)
                } else {
                    await NotificationScheduler.remove(reminder: reminder)
                }
            }
            dismiss()
        } catch {
            HapticFeedback.error.trigger()
            context.rollback()
            errorMessage = error.localizedDescription
        }
    }
}

private enum Weekday: String, CaseIterable, Identifiable {
    case monday, tuesday, wednesday, thursday, friday, saturday, sunday

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        case .sunday: return "Sun"
        }
    }
}
