//
//  AudioGraphs.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 02/10/2025.
//

import AVFoundation
import Charts
import SwiftUI
import os.log

// MARK: - Audio Graph Support
/// Provides audio feedback for visualising symptom patterns
@available(iOS 15.0, *)
class AudioGraphController: NSObject, ObservableObject {
    private var audioPlayer: AVAudioPlayer?
    private let synthesizer = AVSpeechSynthesizer()
    private let logger = Logger(subsystem: "app.murmur", category: "AudioGraphs")

    // Reusable audio engine components to prevent memory leaks
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var currentFormat: AVAudioFormat?
    private var scheduledTones: [DispatchWorkItem] = []

    deinit {
        stopPlayback()
    }

    /// Play audio tones representing severity levels over time
    func sonifySymptomPattern(entries: [SymptomEntry], duration: TimeInterval = 3.0) {
        guard !entries.isEmpty else { return }

        // Cancel any existing playback
        stopPlayback()

        // Sort entries by date
        let sorted = entries.sorted { (lhs, rhs) in
            let lhsDate = lhs.backdatedAt ?? lhs.createdAt ?? Date()
            let rhsDate = rhs.backdatedAt ?? rhs.createdAt ?? Date()
            return lhsDate < rhsDate
        }

        // Announce what we're about to play
        let announcement = "Playing audio graph of \(sorted.count) entries from \(dateRange(for: sorted))"
        speak(announcement)

        // Generate audio tones
        let workItem = DispatchWorkItem { [weak self] in
            self?.playTones(for: sorted, duration: duration)
        }
        scheduledTones.append(workItem)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: workItem)
    }

    /// Play a single data point with speech
    func announceDataPoint(_ entry: SymptomEntry) {
        let symptom = entry.symptomType?.name ?? "Unknown symptom"
        let severity = SeverityScale.descriptor(for: Int(entry.severity))
        let date = entry.backdatedAt ?? entry.createdAt ?? Date()

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let timeText = formatter.localizedString(for: date, relativeTo: Date())

        let text = "\(symptom), \(severity) severity, \(timeText)"
        speak(text)

        // Play corresponding tone
        playTone(frequency: frequencyForSeverity(Int(entry.severity)), duration: 0.3)
    }

    /// Provide audio summary of a day
    func summariseDay(entries: [SymptomEntry], date: Date) {
        guard !entries.isEmpty else {
            speak("No entries for this day")
            return
        }

        // Invert severity for positive symptoms (1-5 becomes 5-1)
        let normalisedSeverities = entries.map { entry -> Double in
            let severity = Double(entry.severity)
            return entry.symptomType?.isPositive == true ? (6.0 - severity) : severity
        }
        let averageSeverity = normalisedSeverities.reduce(0, +) / Double(normalisedSeverities.count)
        let maxSeverity = Int(normalisedSeverities.max() ?? 0)

        let formatter = DateFormatter()
        formatter.dateStyle = .full
        let dateString = formatter.string(from: date)

        var summary = "Summary for \(dateString). "
        summary += "\(entries.count) \(entries.count == 1 ? "entry" : "entries"). "
        summary += "Average severity: \(SeverityScale.descriptor(for: Int(averageSeverity))). "
        summary += "Maximum severity: \(SeverityScale.descriptor(for: maxSeverity))."

        speak(summary)
    }

    /// Stop all audio playback and clean up resources
    func stopPlayback() {
        // Cancel all scheduled tones
        scheduledTones.forEach { $0.cancel() }
        scheduledTones.removeAll()

        // Stop audio playback
        playerNode?.stop()
        audioEngine?.stop()
        audioEngine = nil
        playerNode = nil
        currentFormat = nil
    }

    // MARK: - Private Methods

    private func playTones(for entries: [SymptomEntry], duration: TimeInterval) {
        // Cancel any previously scheduled tones
        scheduledTones.forEach { $0.cancel() }
        scheduledTones.removeAll()

        let timePerEntry = duration / Double(entries.count)

        for (index, entry) in entries.enumerated() {
            let delay = Double(index) * timePerEntry
            let frequency = frequencyForSeverity(Int(entry.severity))

            let workItem = DispatchWorkItem { [weak self] in
                self?.playTone(frequency: frequency, duration: timePerEntry * 0.8)
            }
            scheduledTones.append(workItem)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        }
    }

    private func frequencyForSeverity(_ severity: Int) -> Double {
        // Map severity (1-5) to musical notes
        // Lower severity = lower frequency (more pleasant)
        // Higher severity = higher frequency (more alarming)
        switch severity {
        case 1: return 261.63 // C4
        case 2: return 293.66 // D4
        case 3: return 329.63 // E4
        case 4: return 392.00 // G4
        default: return 523.25 // C5
        }
    }

    private func setupAudioEngineIfNeeded() {
        guard audioEngine == nil else { return }

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 1)

        engine.attach(player)
        if let format = format {
            engine.connect(player, to: engine.mainMixerNode, format: format)
        }

        do {
            try engine.start()
            self.audioEngine = engine
            self.playerNode = player
            self.currentFormat = format
        } catch {
            logger.error("Failed to start audio engine: \(error.localizedDescription)")
        }
    }

    private func playTone(frequency: Double, duration: TimeInterval) {
        setupAudioEngineIfNeeded()

        guard let playerNode = playerNode,
              let format = currentFormat else {
            logger.error("Audio engine not available")
            return
        }

        let sampleRate = 44100.0
        let amplitude = 0.3
        let samples = Int(sampleRate * duration)

        var audioData = [Float]()
        for i in 0..<samples {
            let value = Float(sin(2.0 * Double.pi * frequency * Double(i) / sampleRate) * amplitude)
            audioData.append(value)
        }

        // Create audio buffer
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples)) else { return }

        buffer.frameLength = buffer.frameCapacity
        guard let floatData = buffer.floatChannelData?[0] else { return }

        for i in 0..<samples {
            floatData[i] = audioData[i]
        }

        // Schedule and play the buffer
        playerNode.scheduleBuffer(buffer, at: nil, options: [])
        if !playerNode.isPlaying {
            playerNode.play()
        }
    }

    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-AU")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }

    private func dateRange(for entries: [SymptomEntry]) -> String {
        guard !entries.isEmpty else { return "" }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        if entries.count == 1 {
            let date = entries[0].backdatedAt ?? entries[0].createdAt ?? Date()
            return formatter.string(from: date)
        }

        let firstDate = entries.first?.backdatedAt ?? entries.first?.createdAt ?? Date()
        let lastDate = entries.last?.backdatedAt ?? entries.last?.createdAt ?? Date()

        return "\(formatter.string(from: firstDate)) to \(formatter.string(from: lastDate))"
    }
}

// MARK: - SwiftUI Integration
@available(iOS 15.0, *)
struct AudioGraphButton: View {
    let entries: [SymptomEntry]
    @StateObject private var audioController = AudioGraphController()

    var body: some View {
        Button(action: {
            audioController.sonifySymptomPattern(entries: entries)
        }) {
            Label("Play audio graph", systemImage: "waveform")
        }
        .accessibilityLabel("Play audio representation of symptom pattern")
        .accessibilityHint("Plays tones representing severity levels over time")
        .accessibilityInputLabels(["Play audio graph", "Play sound", "Audio graph", "Hear pattern", "Sonify data"])
    }
}

@available(iOS 15.0, *)
struct DayAudioSummaryButton: View {
    let entries: [SymptomEntry]
    let date: Date
    @StateObject private var audioController = AudioGraphController()

    var body: some View {
        Button(action: {
            audioController.summariseDay(entries: entries, date: date)
        }) {
            Label("Hear summary", systemImage: "speaker.wave.2")
        }
        .accessibilityLabel("Hear audio summary of this day")
        .accessibilityInputLabels(["Hear summary", "Audio summary", "Read summary", "Play summary", "Speak summary"])
    }
}
