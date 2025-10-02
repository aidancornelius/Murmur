import AVFoundation
import Combine
import CoreData
import Speech
import SwiftUI

// MARK: - Voice Command Controller
@available(iOS 15.0, *)
class VoiceCommandController: NSObject, ObservableObject {
    @Published var isListening = false
    @Published var recognisedText = ""
    @Published var feedbackMessage: String?
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    private let speechRecogniser = SFSpeechRecognizer(locale: Locale(identifier: "en-AU"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let synthesizer = AVSpeechSynthesizer()

    private var context: NSManagedObjectContext?

    override init() {
        super.init()
        requestAuthorization()
    }

    func setContext(_ context: NSManagedObjectContext) {
        self.context = context
    }

    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.authorizationStatus = status
            }
        }
    }

    func startListening() {
        guard authorizationStatus == .authorized else {
            feedbackMessage = "Speech recognition not authorised"
            return
        }

        guard !isListening else { return }

        do {
            try startRecognition()
            speak("Listening for command")
        } catch {
            feedbackMessage = "Could not start listening: \(error.localizedDescription)"
        }
    }

    func stopListening() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        isListening = false
        speak("Stopped listening")
    }

    private func startRecognition() throws {
        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw NSError(domain: "VoiceCommand", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create recognition request"])
        }

        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        recognitionTask = speechRecogniser?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                let text = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.recognisedText = text
                    if result.isFinal {
                        self.processCommand(text)
                        self.stopListening()
                    }
                }
            }

            if error != nil {
                self.stopListening()
            }
        }

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        isListening = true
    }

    private func processCommand(_ text: String) {
        let lowercased = text.lowercased()

        // Check for log/record commands
        if lowercased.contains("log") || lowercased.contains("record") {
            handleLogCommand(lowercased)
        }
        // Check for query commands
        else if lowercased.contains("how") || lowercased.contains("what") || lowercased.contains("show") {
            handleQueryCommand(lowercased)
        }
        else {
            speak("I didn't understand that command. Try saying 'log severe headache' or 'show recent entries'")
        }
    }

    private func handleLogCommand(_ command: String) {
        guard let context = context else {
            speak("Unable to save entry")
            return
        }

        // Extract severity
        var severity = 3
        if command.contains("severe") || command.contains("crisis") {
            severity = 5
        } else if command.contains("challenging") || command.contains("moderate") {
            severity = 3
        } else if command.contains("manageable") || command.contains("mild") {
            severity = 2
        } else if command.contains("stable") || command.contains("minimal") {
            severity = 1
        } else if command.contains("level 1") || command.contains("1 out of 5") {
            severity = 1
        } else if command.contains("level 2") || command.contains("2 out of 5") {
            severity = 2
        } else if command.contains("level 3") || command.contains("3 out of 5") {
            severity = 3
        } else if command.contains("level 4") || command.contains("4 out of 5") {
            severity = 4
        } else if command.contains("level 5") || command.contains("5 out of 5") {
            severity = 5
        }

        // Extract symptom type
        let symptomKeywords = extractSymptomKeywords(from: command)

        // Fetch symptom types
        let fetchRequest: NSFetchRequest<SymptomType> = SymptomType.fetchRequest()
        guard let symptomTypes = try? context.fetch(fetchRequest), !symptomTypes.isEmpty else {
            speak("No symptoms configured. Please add symptoms in the app first.")
            return
        }

        // Find matching symptom
        var selectedType: SymptomType?
        for keyword in symptomKeywords {
            if let match = symptomTypes.first(where: { $0.name?.lowercased().contains(keyword) == true }) {
                selectedType = match
                break
            }
        }

        if selectedType == nil {
            // Use first starred or first available
            selectedType = symptomTypes.first(where: { $0.isStarred }) ?? symptomTypes.first
        }

        guard let symptomType = selectedType else {
            speak("Could not determine symptom type")
            return
        }

        // Create entry
        let entry = SymptomEntry(context: context)
        entry.id = UUID()
        entry.createdAt = Date()
        entry.backdatedAt = Date()
        entry.severity = Int16(severity)
        entry.symptomType = symptomType

        do {
            try context.save()
            let severityText = SeverityScale.descriptor(for: severity).lowercased()
            speak("Logged \(symptomType.name ?? "symptom") with \(severityText) severity")
            feedbackMessage = "Entry saved successfully"
        } catch {
            speak("Failed to save entry")
            feedbackMessage = "Error: \(error.localizedDescription)"
        }
    }

    private func handleQueryCommand(_ command: String) {
        guard let context = context else {
            speak("Unable to fetch entries")
            return
        }

        let fetchRequest: NSFetchRequest<SymptomEntry> = SymptomEntry.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \SymptomEntry.backdatedAt, order: .reverse),
            NSSortDescriptor(keyPath: \SymptomEntry.createdAt, order: .reverse)
        ]
        fetchRequest.fetchLimit = 5

        guard let entries = try? context.fetch(fetchRequest), !entries.isEmpty else {
            speak("You haven't logged any symptoms yet")
            return
        }

        if command.contains("recent") || command.contains("last") {
            let count = entries.count
            var summary = "Your \(count) most recent \(count == 1 ? "entry" : "entries"): "

            for (index, entry) in entries.enumerated() {
                let symptom = entry.symptomType?.name ?? "Unknown"
                let severity = SeverityScale.descriptor(for: Int(entry.severity))
                summary += "\(symptom), \(severity)"

                if index < entries.count - 1 {
                    summary += ". "
                }
            }

            speak(summary)
        } else if command.contains("today") {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())

            let todayEntries = entries.filter {
                let entryDate = $0.backdatedAt ?? $0.createdAt ?? Date()
                return calendar.isDate(entryDate, inSameDayAs: today)
            }

            if todayEntries.isEmpty {
                speak("No entries for today")
            } else {
                speak("You've logged \(todayEntries.count) \(todayEntries.count == 1 ? "entry" : "entries") today")
            }
        }
    }

    private func extractSymptomKeywords(from text: String) -> [String] {
        var keywords: [String] = []

        // Common symptom keywords
        let symptomWords = ["headache", "migraine", "fatigue", "pain", "nausea", "anxiety", "depression",
                           "stress", "insomnia", "dizziness", "fever", "cough", "brain fog"]

        for word in symptomWords {
            if text.contains(word) {
                keywords.append(word)
            }
        }

        return keywords
    }

    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-AU")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)

        DispatchQueue.main.async {
            self.feedbackMessage = text
        }
    }
}

// MARK: - SwiftUI Integration
@available(iOS 15.0, *)
struct VoiceCommandButton: View {
    @EnvironmentObject var voiceController: VoiceCommandController

    var body: some View {
        Button(action: {
            if voiceController.isListening {
                voiceController.stopListening()
            } else {
                voiceController.startListening()
            }
        }) {
            Label(voiceController.isListening ? "Stop listening" : "Voice command",
                  systemImage: voiceController.isListening ? "mic.fill" : "mic")
        }
        .disabled(voiceController.authorizationStatus != .authorized)
        .accessibilityLabel(voiceController.isListening ? "Stop voice command" : "Start voice command")
        .accessibilityHint("Use voice to log symptoms hands-free")
    }
}

@available(iOS 15.0, *)
struct VoiceCommandView: View {
    @StateObject private var voiceController = VoiceCommandController()
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: voiceController.isListening ? "waveform" : "mic.circle")
                .font(.system(size: 80))
                .foregroundStyle(voiceController.isListening ? .blue : .secondary)
                .symbolEffect(.pulse, isActive: voiceController.isListening)

            Text(voiceController.isListening ? "Listening..." : "Tap to speak")
                .font(.title2)
                .fontWeight(.semibold)

            if !voiceController.recognisedText.isEmpty {
                Text(voiceController.recognisedText)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if let feedback = voiceController.feedbackMessage {
                Text(feedback)
                    .font(.callout)
                    .foregroundStyle(.blue)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button(action: {
                if voiceController.isListening {
                    voiceController.stopListening()
                } else {
                    voiceController.startListening()
                }
            }) {
                Text(voiceController.isListening ? "Stop listening" : "Start listening")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(voiceController.isListening ? Color.red : Color.blue, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
            .disabled(voiceController.authorizationStatus != .authorized)

            VStack(alignment: .leading, spacing: 8) {
                Text("Examples:")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                Text("• \"Log severe headache\"")
                Text("• \"Record manageable fatigue\"")
                Text("• \"Show recent entries\"")
                Text("• \"What did I log today\"")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)

            Spacer()
        }
        .padding()
        .navigationTitle("Voice commands")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            voiceController.setContext(context)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    if voiceController.isListening {
                        voiceController.stopListening()
                    }
                    dismiss()
                }
            }
        }
    }
}
