import SwiftUI

struct ReminderListView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(
        entity: Reminder.entity(),
        sortDescriptors: [NSSortDescriptor(key: "hour", ascending: true), NSSortDescriptor(key: "minute", ascending: true)]
    ) private var reminders: FetchedResults<Reminder>

    @State private var presentingForm = false
    @State private var selectedReminder: Reminder?

    var body: some View {
        List {
            Section {
                Text("Gentle reminders can help you check in with yourself regularly. Tracking consistently makes it easier to spot patterns and understand what helps you feel better. Add one with the button above.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }

            ForEach(reminders) { reminder in
                HStack {
                    VStack(alignment: .leading) {
                        Text(timeString(for: reminder))
                            .font(.headline)
                        if let repeats = reminder.repeatsOn as? [String], !repeats.isEmpty {
                            Text(repeats.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Toggle("Enabled", isOn: Binding(
                        get: { reminder.isEnabled },
                        set: { newValue in
                            reminder.isEnabled = newValue
                            try? context.save()
                            Task {
                                if newValue {
                                    try? await NotificationScheduler.schedule(reminder: reminder)
                                } else {
                                    NotificationScheduler.remove(reminder: reminder)
                                }
                            }
                        }
                    ))
                    .labelsHidden()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedReminder = reminder
                    presentingForm = true
                }
            }
            .onDelete(perform: delete)
        }
        .navigationTitle("Reminders")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    selectedReminder = nil
                    presentingForm = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $presentingForm) {
            NavigationStack {
                ReminderFormView(editingReminder: selectedReminder)
            }
        }
    }

    private func timeString(for reminder: Reminder) -> String {
        let components = DateComponents(hour: Int(reminder.hour), minute: Int(reminder.minute))
        let calendar = Calendar.current
        if let date = calendar.date(from: components) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        return "--"
    }

    private func delete(at offsets: IndexSet) {
        offsets.map { reminders[$0] }.forEach { reminder in
            NotificationScheduler.remove(reminder: reminder)
            context.delete(reminder)
        }
        try? context.save()
    }
}
