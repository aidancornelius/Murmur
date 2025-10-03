import CoreData
import PDFKit
import SwiftUI

/// Exports all symptom entries to a formatted PDF document
@MainActor
struct PDFExporter {
    private let stack: CoreDataStack

    init(stack: CoreDataStack = .shared) {
        self.stack = stack
    }

    func exportToPDF() async throws -> URL {
        let entries = try await fetchAllEntries()
        let pdfData = try generatePDF(entries: entries)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Murmur_Export_\(Date().ISO8601Format()).pdf")
        try pdfData.write(to: tempURL)

        return tempURL
    }

    private func fetchAllEntries() async throws -> [SymptomEntry] {
        let context = stack.container.viewContext
        let request = SymptomEntry.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SymptomEntry.createdAt, ascending: false)]
        request.relationshipKeyPathsForPrefetching = ["symptomType"]

        return try context.fetch(request)
    }

    private func generatePDF(entries: [SymptomEntry]) throws -> Data {
        let pageSize = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        let renderer = UIGraphicsPDFRenderer(bounds: pageSize)

        let data = renderer.pdfData { context in
            var yPosition: CGFloat = 60
            let margin: CGFloat = 40
            let contentWidth = pageSize.width - (margin * 2)

            context.beginPage()

            // Title
            let titleFont = UIFont.boldSystemFont(ofSize: 24)
            let title = "Murmur symptom export"
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.label
            ]
            title.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: titleAttributes)
            yPosition += 30

            // Date range
            let subtitleFont = UIFont.systemFont(ofSize: 12)
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            let exportDate = "Exported on \(dateFormatter.string(from: Date()))"
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: subtitleFont,
                .foregroundColor: UIColor.secondaryLabel
            ]
            exportDate.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: subtitleAttributes)
            yPosition += 20

            let entryCount = "\(entries.count) total entries"
            entryCount.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: subtitleAttributes)
            yPosition += 40

            // Entries
            let headerFont = UIFont.boldSystemFont(ofSize: 14)
            let bodyFont = UIFont.systemFont(ofSize: 11)
            let captionFont = UIFont.systemFont(ofSize: 9)

            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short

            for entry in entries {
                // Check if we need a new page
                if yPosition > pageSize.height - 150 {
                    context.beginPage()
                    yPosition = 60
                }

                // Entry header
                let symptomName = entry.symptomType?.safeName ?? "Unknown symptom"
                let headerAttributes: [NSAttributedString.Key: Any] = [
                    .font: headerFont,
                    .foregroundColor: UIColor.label
                ]
                symptomName.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: headerAttributes)
                yPosition += 20

                // Date and severity
                let bodyAttributes: [NSAttributedString.Key: Any] = [
                    .font: bodyFont,
                    .foregroundColor: UIColor.label
                ]
                let captionAttributes: [NSAttributedString.Key: Any] = [
                    .font: captionFont,
                    .foregroundColor: UIColor.secondaryLabel
                ]

                let dateStr = dateFormatter.string(from: entry.effectiveDate)
                dateStr.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: bodyAttributes)
                yPosition += 15

                let severityStr = "Severity: \(entry.severity)/5"
                severityStr.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: bodyAttributes)
                yPosition += 15

                // Note
                if let note = entry.note, !note.isEmpty {
                    let noteRect = CGRect(x: margin, y: yPosition, width: contentWidth, height: 1000)
                    let noteText = "Note: \(note)"
                    let boundingRect = noteText.boundingRect(
                        with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                        options: [.usesLineFragmentOrigin],
                        attributes: bodyAttributes,
                        context: nil
                    )
                    noteText.draw(in: noteRect, withAttributes: bodyAttributes)
                    yPosition += boundingRect.height + 10
                }

                // Health data if available
                var healthDataParts: [String] = []
                if let hrv = entry.hkHRV {
                    healthDataParts.append("HRV: \(hrv)ms")
                }
                if let hr = entry.hkRestingHR {
                    healthDataParts.append("Resting HR: \(hr)bpm")
                }
                if let sleep = entry.hkSleepHours {
                    healthDataParts.append("Sleep: \(String(format: "%.1f", sleep.doubleValue))h")
                }
                if let workout = entry.hkWorkoutMinutes {
                    healthDataParts.append("Workout: \(workout)min")
                }
                if let cycleDay = entry.hkCycleDay {
                    healthDataParts.append("Cycle day: \(cycleDay)")
                }

                if !healthDataParts.isEmpty {
                    let healthStr = healthDataParts.joined(separator: " • ")
                    healthStr.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: captionAttributes)
                    yPosition += 12
                }

                // Location if available
                if let placemark = entry.locationPlacemark {
                    var locationParts: [String] = []
                    if let locality = placemark.locality {
                        locationParts.append(locality)
                    }
                    if let area = placemark.administrativeArea {
                        locationParts.append(area)
                    }
                    if !locationParts.isEmpty {
                        let locationStr = "Location: \(locationParts.joined(separator: ", "))"
                        locationStr.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: captionAttributes)
                        yPosition += 12
                    }
                }

                // Separator
                yPosition += 10
                let separator = UIBezierPath()
                separator.move(to: CGPoint(x: margin, y: yPosition))
                separator.addLine(to: CGPoint(x: pageSize.width - margin, y: yPosition))
                UIColor.separator.setStroke()
                separator.lineWidth = 0.5
                separator.stroke()
                yPosition += 20
            }

            // Footer on last page
            let footerFont = UIFont.systemFont(ofSize: 9)
            let footerAttributes: [NSAttributedString.Key: Any] = [
                .font: footerFont,
                .foregroundColor: UIColor.secondaryLabel
            ]
            let footer = "Generated by Murmur"
            footer.draw(
                at: CGPoint(x: margin, y: pageSize.height - 30),
                withAttributes: footerAttributes
            )
        }

        return data
    }
}
