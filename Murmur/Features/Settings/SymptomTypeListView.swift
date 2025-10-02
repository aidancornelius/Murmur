import SwiftUI
import CoreData

struct SymptomTypeListView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(
        entity: SymptomType.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \SymptomType.isDefault, ascending: true),
            NSSortDescriptor(keyPath: \SymptomType.name, ascending: true)
        ]
    ) private var types: FetchedResults<SymptomType>

    @State private var editingType: SymptomType?
    @State private var presentingForm = false

    var body: some View {
        List {
            Section {
                Text("Track the symptoms that matter to you. Your custom symptoms help you notice patterns and understand what affects your wellbeing. Add one with the button above.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }

            ForEach(types) { type in
                NavigationLink(value: type.objectID) {
                    HStack {
                        Circle()
                            .fill(type.uiColor)
                            .frame(width: 18, height: 18)
                        Text(type.name ?? "Unnamed")
                        Spacer()
                        if type.isDefault {
                            Text("Default")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Image(systemName: type.iconName ?? "circle")
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityLabel("\(type.name ?? "Unnamed")\(type.isDefault ? ", default symptom" : "")")
                .accessibilityHint("Double tap to edit this symptom")
            }
            .onDelete(perform: delete)
        }
        .navigationTitle("Tracked symptoms")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editingType = nil
                    presentingForm = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add symptom")
                .accessibilityHint("Creates a new custom symptom to track")
            }
        }
        .sheet(isPresented: $presentingForm) {
            NavigationStack {
                SymptomTypeFormView(editingType: editingType)
                    .environment(\.managedObjectContext, context)
            }
        }
        .navigationDestination(for: NSManagedObjectID.self) { objectID in
            if let type = try? context.existingObject(with: objectID) as? SymptomType {
                SymptomTypeFormView(editingType: type)
                    .environment(\.managedObjectContext, context)
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        offsets.map { types[$0] }
            .filter { !$0.isDefault } // Only delete non-default symptoms
            .forEach(context.delete)
        if (try? context.save()) != nil {
            HapticFeedback.success.trigger()
        }
    }
}
