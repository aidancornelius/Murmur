// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// SpeechService.swift
// Created by Aidan Cornelius-Bell on 07/10/2025.
// Service for speech recognition input.
//
import AVFoundation
import Combine
import os.log

// MARK: - Voice Selection Utility
/// Utility for selecting the best available speech voice
struct VoiceSelector {
    private static let logger = Logger(subsystem: "app.murmur", category: "VoiceSelector")

    /// Get the best available voice in the user's system language
    static func bestAvailableVoice() -> AVSpeechSynthesisVoice? {
        // Get user's preferred language
        let preferredLanguages = Locale.preferredLanguages
        guard let primaryLanguage = preferredLanguages.first else {
            logger.warning("No preferred language found, falling back to en-US")
            return bestVoiceForLanguage("en-US")
        }

        // Convert from language identifier to voice language code (e.g., "en-AU" stays "en-AU", "en" becomes "en-US")
        let voiceLanguage = languageCodeForVoice(from: primaryLanguage)
        logger.info("User preferred language: \(primaryLanguage), voice language: \(voiceLanguage)")

        return bestVoiceForLanguage(voiceLanguage)
    }

    /// Get the best available voice for a specific language
    private static func bestVoiceForLanguage(_ languageCode: String) -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()

        // Extract base language (e.g., "en" from "en-AU")
        let baseLanguage = String(languageCode.prefix(2))

        // Log available voices for this language
        let matchingVoices = voices.filter { $0.language.hasPrefix(baseLanguage) }
        logger.info("Available \(baseLanguage) voices: \(matchingVoices.map { "\($0.name) (\($0.language)) - quality: \(String(describing: $0.quality.rawValue))" }.joined(separator: ", "))")

        // Try to find voice matching exact language code with highest quality
        let qualityOrder: [AVSpeechSynthesisVoiceQuality] = [.premium, .enhanced, .default]

        // First pass: exact language match (e.g., "en-AU")
        for quality in qualityOrder {
            if let voice = voices.first(where: { $0.language == languageCode && $0.quality == quality }) {
                logger.info("Using exact match voice: \(voice.name) (\(voice.identifier)) - quality: \(quality.rawValue)")
                return voice
            }
        }

        // Second pass: base language match (e.g., "en" matches "en-US", "en-GB", etc.)
        for quality in qualityOrder {
            if let voice = voices.first(where: { $0.language.hasPrefix(baseLanguage) && $0.quality == quality }) {
                logger.info("Using base language match voice: \(voice.name) (\(voice.identifier)) - quality: \(quality.rawValue)")
                return voice
            }
        }

        // Last resort: system default for language
        let fallback = AVSpeechSynthesisVoice(language: languageCode)
        logger.warning("Using default fallback voice for \(languageCode)")
        return fallback
    }

    /// Convert language identifier to voice language code
    private static func languageCodeForVoice(from identifier: String) -> String {
        // If it already looks like a voice code (e.g., "en-AU"), use it
        if identifier.contains("-") && identifier.count <= 5 {
            return identifier
        }

        // Parse locale identifier
        let locale = Locale(identifier: identifier)

        if let languageCode = locale.language.languageCode?.identifier,
           let regionCode = locale.region?.identifier {
            return "\(languageCode)-\(regionCode)"
        } else if let languageCode = locale.language.languageCode?.identifier {
            // No region specified, use common default
            switch languageCode {
            case "en": return "en-US"
            case "es": return "es-ES"
            case "fr": return "fr-FR"
            case "de": return "de-DE"
            case "it": return "it-IT"
            case "ja": return "ja-JP"
            case "zh": return "zh-CN"
            case "pt": return "pt-BR"
            default: return "\(languageCode)-\(languageCode.uppercased())"
            }
        }

        return "en-US"
    }
}

// MARK: - Speech Service
/// Centralised service for text-to-speech functionality
@MainActor
class SpeechService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = SpeechService()

    private let synthesizer = AVSpeechSynthesizer()
    private let logger = Logger(subsystem: "app.murmur", category: "SpeechService")

    // Pending action to execute after speech completes
    private var pendingAction: (() -> Void)?

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Speak text using the best available voice
    func speak(_ text: String, completion: (() -> Void)? = nil) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = VoiceSelector.bestAvailableVoice()
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate

        pendingAction = completion

        synthesizer.speak(utterance)
        logger.debug("Speaking: \(text)")
    }

    /// Stop all speech immediately
    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        pendingAction = nil
        logger.debug("Stopped speaking")
    }

    /// Check if currently speaking
    var isSpeaking: Bool {
        synthesizer.isSpeaking
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // Execute any pending action after speech completes with a small delay to ensure audio is clear
        Task { @MainActor in
            let action = self.pendingAction
            self.pendingAction = nil

            if let action = action {
                // Small delay to ensure audio is clear
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                action()
            }
        }
    }
}
