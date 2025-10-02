import SwiftUI
import CoreData

struct SymptomTypeFormView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    let editingType: SymptomType?

    @State private var name: String = ""
    @State private var colorHex: String = "#6FA8DC"
    @State private var iconName: String = "heart.fill"
    @State private var isStarred: Bool = false
    @State private var starOrder: Int = 0
    @State private var errorMessage: String?

    private let colorPalette = ["#6FA8DC", "#76C7C0", "#FFD966", "#F4B183", "#C27BA0", "#E06666", "#F5A3A3", "#8DC6D2", "#FFB570", "#B07BB4", "#A678B0"]
    private let iconOptions = ["heart.fill", "bolt.horizontal.circle", "dumbbell", "figure.stand", "brain", "heart.circle", "moon.zzz", "waveform.path.ecg", "bandage", "heart.text.square", "fork.knife", "lungs.fill", "sparkles"]

    init(editingType: SymptomType?) {
        self.editingType = editingType
        _name = State(initialValue: editingType?.name ?? "")
        _colorHex = State(initialValue: editingType?.color ?? "#6FA8DC")
        _iconName = State(initialValue: editingType?.iconName ?? "heart.fill")
        _isStarred = State(initialValue: editingType?.isStarred ?? false)
        _starOrder = State(initialValue: Int(editingType?.starOrder ?? 0))
    }

    var body: some View {
        Form {
            Section {
                TextField("Symptom name", text: $name)
            }

            Section("Color") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(colorPalette, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 36, height: 36)
                                .overlay {
                                    if hex == colorHex {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.white)
                                    }
                                }
                                .onTapGesture {
                                    HapticFeedback.selection.trigger()
                                    colorHex = hex
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("Icon") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4), spacing: 12) {
                    ForEach(iconOptions, id: \.self) { icon in
                        Image(systemName: icon)
                            .frame(width: 44, height: 44)
                            .background(RoundedRectangle(cornerRadius: 10).stroke(icon == iconName ? Color.accentColor : .gray.opacity(0.2)))
                            .onTapGesture {
                                HapticFeedback.selection.trigger()
                                iconName = icon
                            }
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                Toggle("Show first when logging", isOn: $isStarred)
                    .onChange(of: isStarred) { _, _ in
                        HapticFeedback.selection.trigger()
                    }
                if isStarred {
                    Stepper("Priority: \(starOrder)", value: $starOrder, in: 0...100)
                        .font(.callout)
                }
            } footer: {
                Text("Your starred symptoms appear first when logging (we recommend 5 or fewer).")
                    .font(.caption)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(editingType == nil ? "Add a symptom" : "Update symptom")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", role: .cancel) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Please give this symptom a name."
            return
        }

        let target: SymptomType
        if let editingType {
            target = editingType
        } else {
            target = SymptomType(context: context)
            target.id = UUID()
            target.category = nil // User-added symptoms have no category
            target.isDefault = false
        }

        target.name = trimmed
        target.color = colorHex
        target.iconName = iconName
        target.isStarred = isStarred
        target.starOrder = Int16(starOrder)

        do {
            if context.hasChanges {
                try context.save()
                HapticFeedback.success.trigger()
            }
            dismiss()
        } catch {
            HapticFeedback.error.trigger()
            errorMessage = error.localizedDescription
            context.rollback()
        }
    }
}
