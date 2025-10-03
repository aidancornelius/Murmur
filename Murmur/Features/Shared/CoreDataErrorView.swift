import SwiftUI

struct CoreDataErrorView: View {
    let error: CoreDataStack.CoreDataError

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)

            Text("Data storage error")
                .font(.title)
                .fontWeight(.semibold)

            Text(error.localizedDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(spacing: 12) {
                Text("Please try:")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    Label("Force quit and restart the app", systemImage: "arrow.clockwise")
                    Label("Free up storage space", systemImage: "internaldrive")
                    Label("Update to the latest version", systemImage: "arrow.down.circle")
                }
                .font(.callout)
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)

            Button(action: {
                // Attempt to restart the app
                exit(0)
            }) {
                Text("Restart app")
                    .fontWeight(.medium)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
    }
}