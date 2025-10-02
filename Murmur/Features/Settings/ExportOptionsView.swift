import SwiftUI

struct ExportOptionsView: View {
    @State private var isExporting = false
    @State private var pdfURL: URL?
    @State private var showShareSheet = false
    @State private var errorMessage: String?
    private let pdfExporter = PDFExporter()

    var body: some View {
        VStack(spacing: 20) {
            if isExporting {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Generating PDF...")
                        .font(.headline)
                    Text("Please wait whilst we export your entries")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)
                        .padding(.top, 40)

                    Text("Export to PDF")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Create a PDF document with all your symptom entries")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Spacer()

                    Button(action: createPDFExport) {
                        Label("Export all entries", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                }
            }
        }
        .navigationTitle("Export your data")
        .sheet(isPresented: $showShareSheet) {
            if let pdfURL {
                ShareSheet(items: [pdfURL])
            }
        }
    }

    private func createPDFExport() {
        isExporting = true
        errorMessage = nil

        Task {
            do {
                let url = try await pdfExporter.exportToPDF()
                await MainActor.run {
                    pdfURL = url
                    isExporting = false
                    showShareSheet = true
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    errorMessage = "Failed to create PDF: \(error.localizedDescription)"
                }
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
