//
//  ExportOptionsView.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 02/10/2025.
//

import SwiftUI

struct ExportOptionsView: View {
    @EnvironmentObject private var appearanceManager: AppearanceManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var isExporting = false
    @State private var pdfURL: URL?
    @State private var showShareSheet = false
    @State private var errorMessage: String?
    private let pdfExporter = PDFExporter()

    private var palette: ColorPalette {
        appearanceManager.currentPalette(for: colorScheme)
    }

    var body: some View {
        Form {
            Section {
                Text("Create a PDF document containing all your symptom entries for your records or to share with healthcare providers.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }

            Section("Export") {
                Button {
                    createPDFExport()
                } label: {
                    Label("Export all entries", systemImage: "square.and.arrow.up")
                }
                .disabled(isExporting)

                Text("Generates a PDF with your complete symptom history")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(palette.surfaceColor)

            if isExporting {
                Section {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Generating PDF...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(palette.surfaceColor)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .listRowBackground(palette.surfaceColor)
            }
        }
        .navigationTitle("Export entries")
        .navigationBarTitleDisplayMode(.large)
        .themedScrollBackground()
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
