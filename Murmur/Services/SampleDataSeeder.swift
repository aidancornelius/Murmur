import CoreData
import Foundation
import os.log

struct SampleDataSeeder {
    private static let logger = Logger(subsystem: "app.murmur", category: "SampleData")

    #if targetEnvironment(simulator)
    /// Generates realistic sample timeline entries for simulator testing
    static func generateSampleEntries(in context: NSManagedObjectContext) {
        let stackContext = CoreDataStack.shared.context
        stackContext.perform {
            // Fetch existing symptom types
            let typeRequest: NSFetchRequest<SymptomType> = SymptomType.fetchRequest()
            guard let types = try? stackContext.fetch(typeRequest), !types.isEmpty else {
                logger.warning("No symptom types found - seed default types first")
                return
            }

            // Generate entries over the past 60 days
            let now = Date()
            let calendar = Calendar.current

            // Define some common symptom patterns
            let commonSymptoms = types.filter { symptom in
                ["Fatigue", "Brain fog", "Headache", "Muscle pain", "Joint pain", "Anxiety", "Insomnia"].contains(symptom.name ?? "")
            }

            let occasionalSymptoms = types.filter { symptom in
                !commonSymptoms.contains(symptom)
            }

            // Sample activities for realistic load tracking
            let sampleActivities: [(name: String, physical: Int16, cognitive: Int16, emotional: Int16, duration: Int)] = [
                // Light activities
                ("Morning shower", 2, 1, 1, 15),
                ("Making breakfast", 2, 1, 1, 20),
                ("Reading", 1, 2, 1, 30),
                ("Watching TV", 1, 1, 1, 60),
                ("Gentle stretching", 2, 1, 1, 10),
                // Moderate activities
                ("Short walk", 3, 2, 2, 20),
                ("Cooking lunch", 3, 2, 1, 30),
                ("Video call with friend", 1, 2, 3, 45),
                ("Light housework", 3, 2, 2, 30),
                ("Grocery shopping", 3, 3, 2, 40),
                ("Medical appointment", 2, 3, 3, 60),
                // Higher exertion
                ("Work meeting", 2, 4, 3, 60),
                ("Deep work session", 1, 5, 2, 90),
                ("Social event", 3, 3, 4, 120),
                ("Cleaning house", 4, 2, 2, 45),
                ("Physical therapy", 4, 2, 2, 45),
                ("Extended family visit", 2, 3, 4, 180)
            ]

            for dayOffset in 0..<60 {
                guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }

                // Determine daily pattern (some days worse than others)
                let isFlareDay = (dayOffset % 7 == 0 || dayOffset % 11 == 0) // Periodic flares
                let isBetterDay = (dayOffset % 5 == 4) // Some better days
                let isRestDay = (dayOffset % 6 == 0) // Scheduled rest days

                let entryCount = isFlareDay ? Int.random(in: 4...8) : (isBetterDay ? Int.random(in: 1...2) : Int.random(in: 2...4))

                // Generate activities (fewer on flare/rest days)
                let activityCount: Int
                if isRestDay {
                    activityCount = Int.random(in: 1...2) // Minimal activities on rest days
                } else if isFlareDay {
                    activityCount = Int.random(in: 1...3) // Limited activities on flare days
                } else if isBetterDay {
                    activityCount = Int.random(in: 3...5) // More activities on better days
                } else {
                    activityCount = Int.random(in: 2...4) // Normal day
                }

                // Add activities for the day
                for activityIndex in 0..<activityCount {
                    let activity = ActivityEvent(context: stackContext)
                    activity.id = UUID()

                    // Spread activities throughout the day (8am to 8pm)
                    let hourOffset = 8 + (activityIndex * (12 / max(activityCount, 1)))
                    let minuteOffset = Int.random(in: 0..<60)
                    guard let activityDate = calendar.date(bySettingHour: hourOffset, minute: minuteOffset, second: 0, of: date) else { continue }

                    activity.createdAt = activityDate
                    activity.backdatedAt = activityDate

                    // Select appropriate activity based on day type
                    let availableActivities: [(name: String, physical: Int16, cognitive: Int16, emotional: Int16, duration: Int)]
                    if isFlareDay || isRestDay {
                        // Only light activities on bad/rest days
                        availableActivities = Array(sampleActivities.prefix(5))
                    } else if isBetterDay {
                        // Can do higher exertion on better days
                        availableActivities = sampleActivities
                    } else {
                        // Light to moderate on normal days
                        availableActivities = Array(sampleActivities.prefix(10))
                    }

                    let selectedActivity = availableActivities.randomElement() ?? sampleActivities[0]
                    activity.name = selectedActivity.name
                    activity.physicalExertion = selectedActivity.physical
                    activity.cognitiveExertion = selectedActivity.cognitive
                    activity.emotionalLoad = selectedActivity.emotional
                    activity.durationMinutes = NSNumber(value: selectedActivity.duration)

                    // Add notes to some activities
                    if Double.random(in: 0...1) < 0.2 {
                        let activityNotes = [
                            "Felt okay during this",
                            "Had to take breaks",
                            "Pushed through fatigue",
                            "Paced well",
                            "Overdid it",
                            "Needed rest after",
                            "Manageable today"
                        ]
                        activity.note = activityNotes.randomElement()
                    }
                }

                for entryIndex in 0..<entryCount {
                    let entry = SymptomEntry(context: stackContext)
                    entry.id = UUID()

                    // Spread entries throughout the day
                    let hourOffset = entryIndex * (24 / max(entryCount, 1))
                    let minuteOffset = Int.random(in: 0..<60)
                    guard let entryDate = calendar.date(byAdding: .hour, value: hourOffset, to: date),
                          let finalDate = calendar.date(byAdding: .minute, value: minuteOffset, to: entryDate) else { continue }

                    entry.createdAt = finalDate
                    entry.backdatedAt = finalDate

                    // Choose symptom type based on frequency
                    let useCommon = Double.random(in: 0...1) < 0.7
                    let symptomPool = useCommon ? commonSymptoms : occasionalSymptoms
                    entry.symptomType = symptomPool.randomElement() ?? types.randomElement()

                    // Set severity - worse on flare days
                    if isFlareDay {
                        entry.severity = Int16.random(in: 4...5)
                    } else if isBetterDay {
                        entry.severity = Int16.random(in: 1...2)
                    } else {
                        entry.severity = Int16.random(in: 2...4)
                    }

                    // Add notes to some entries
                    if Double.random(in: 0...1) < 0.3 {
                        let notes = [
                            "Worse after activity",
                            "Improving gradually",
                            "Triggered by stress",
                            "Affecting sleep",
                            "Better with rest",
                            "No clear trigger",
                            "Started suddenly",
                            "Persistent today",
                            "Manageable",
                            "Very challenging"
                        ]
                        entry.note = notes.randomElement()
                    }

                    // Add realistic health metrics
                    // HRV: lower on bad days, higher on good days
                    if Double.random(in: 0...1) < 0.6 {
                        let baseHRV = isBetterDay ? 55.0 : (isFlareDay ? 25.0 : 40.0)
                        entry.hkHRV = NSNumber(value: baseHRV + Double.random(in: -10...10))
                    }

                    // Resting HR: higher on flare days
                    if Double.random(in: 0...1) < 0.6 {
                        let baseHR = isFlareDay ? 75.0 : (isBetterDay ? 58.0 : 65.0)
                        entry.hkRestingHR = NSNumber(value: baseHR + Double.random(in: -5...5))
                    }

                    // Sleep: worse on flare days
                    if Double.random(in: 0...1) < 0.5 {
                        let baseSleep = isFlareDay ? 5.0 : (isBetterDay ? 8.5 : 6.5)
                        entry.hkSleepHours = NSNumber(value: max(3.0, baseSleep + Double.random(in: -1.5...1.5)))
                    }

                    // Workout: less on flare days, more on better days
                    if Double.random(in: 0...1) < 0.3 {
                        let baseWorkout = isFlareDay ? 0.0 : (isBetterDay ? 25.0 : 10.0)
                        entry.hkWorkoutMinutes = NSNumber(value: max(0.0, baseWorkout + Double.random(in: -10...10)))
                    }

                    // Cycle tracking (if applicable)
                    if Double.random(in: 0...1) < 0.4 { // 40% chance of cycle tracking
                        let cycleLength = 28
                        let cycleDay = (dayOffset % cycleLength) + 1
                        entry.hkCycleDay = NSNumber(value: cycleDay)

                        // Flow level during menstruation
                        if cycleDay >= 1 && cycleDay <= 5 {
                            let flowLevels = ["light", "medium", "heavy"]
                            entry.hkFlowLevel = flowLevels.randomElement()
                        }
                    }
                }
            }

            try? stackContext.save()
            logger.info("Generated sample timeline entries (symptoms and activities) for simulator")
        }
    }
    #endif

    static func seedIfNeeded(in context: NSManagedObjectContext) {
        let stackContext = CoreDataStack.shared.context
        stackContext.perform {
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = SymptomType.fetchRequest()
            fetchRequest.fetchLimit = 1
            let existingCount = (try? stackContext.count(for: fetchRequest)) ?? 0
            guard existingCount == 0 else { return }

            let defaults: [(name: String, color: String, icon: String, category: String)] = [
                // Energy
                ("Post-Exertional Malaise (PEM)", "#F5A3A3", "bolt.horizontal.circle", "Energy"),
                ("Fatigue", "#FFD966", "bolt.slash", "Energy"),
                ("Weakness", "#E8C89F", "figure.stand.line.dotted.figure.stand", "Energy"),

                // Pain
                ("Headache", "#E06666", "bandage", "Pain"),
                ("Migraine", "#D45E5E", "bolt.fill", "Pain"),
                ("Muscle pain", "#C27BA0", "figure.arms.open", "Pain"),
                ("Joint pain", "#A678B0", "figure.stand", "Pain"),
                ("Widespread pain", "#D8A1C0", "figure.wave", "Pain"),
                ("Tender points", "#E8B5D4", "hand.point.up.braille", "Pain"),
                ("Muscle stiffness", "#C99CB8", "figure.flexibility", "Pain"),
                ("Back pain", "#B88AA6", "figure.walk", "Pain"),
                ("Nerve pain", "#E67E9F", "bolt.badge.clock", "Pain"),
                ("Chest pain", "#E08E8E", "heart.slash", "Pain"),
                ("Stomach pain", "#FFD4A3", "cross.circle", "Pain"),

                // Cognitive
                ("Brain fog", "#6FA8DC", "brain", "Cognitive"),
                ("Cognitive difficulties", "#9BC4E8", "brain.head.profile", "Cognitive"),
                ("Difficulty concentrating", "#A8D5F2", "text.magnifyingglass", "Cognitive"),
                ("Memory problems", "#7FB3D5", "questionmark.circle", "Cognitive"),

                // Sleep
                ("Unrefreshing sleep", "#B4A7D6", "moon.zzz", "Sleep"),
                ("Insomnia", "#C5B8D6", "moon.stars", "Sleep"),
                ("Nightmares", "#9D88B3", "moon.haze", "Sleep"),
                ("Restless sleep", "#B5A8C9", "bed.double", "Sleep"),

                // Neurological
                ("Dizziness", "#76C7C0", "arrow.triangle.2.circlepath", "Neurological"),
                ("Orthostatic intolerance", "#8DC6D2", "heart.circle", "Neurological"),
                ("Light/Sound sensitivity", "#FFB570", "waveform.path.ecg", "Neurological"),
                ("Numbness/Tingling", "#D4A5D9", "hand.raised.fingers.spread", "Neurological"),
                ("Tremors", "#C8B6D9", "hand.tap", "Neurological"),
                ("Coordination problems", "#D4BFA8", "figure.fall", "Neurological"),
                ("Vision problems", "#A8C5D9", "eye.trianglebadge.exclamationmark", "Neurological"),
                ("Ringing in ears (tinnitus)", "#D9C1A8", "ear", "Neurological"),

                // Digestive
                ("Nausea", "#F4B183", "fork.knife", "Digestive"),
                ("Bloating", "#FFE4B8", "circle.hexagongrid", "Digestive"),
                ("Constipation", "#F5D4A8", "arrow.down.circle", "Digestive"),
                ("Diarrhea", "#FFDBB3", "arrow.down.to.line.compact", "Digestive"),
                ("IBS symptoms", "#FFE8C3", "exclamationmark.triangle", "Digestive"),

                // Mental health
                ("Anxiety", "#B8D4E0", "cloud", "Mental health"),
                ("Depression", "#8FB4C9", "cloud.rain", "Mental health"),
                ("Panic", "#A5C8DB", "exclamationmark.bubble", "Mental health"),
                ("Flashbacks", "#C9DEE8", "arrow.counterclockwise", "Mental health"),
                ("Hypervigilance", "#D1E5F0", "eye", "Mental health"),
                ("Dissociation", "#B3D3E3", "eye.slash", "Mental health"),

                // Respiratory & cardiovascular
                ("Palpitations", "#F39C9C", "waveform.path.ecg.rectangle", "Respiratory & cardiovascular"),
                ("Shortness of breath", "#A6D9E8", "lungs", "Respiratory & cardiovascular"),
                ("Sore throat", "#FF9AA2", "mouth", "Respiratory & cardiovascular"),

                // Other
                ("Flu-like symptoms", "#FFB8C6", "cross.case", "Other"),
                ("Swollen lymph nodes", "#FFC3A0", "heart.text.square", "Other"),
                ("Temperature dysregulation", "#FFCBA4", "thermometer.medium", "Other"),
                ("Inflammation", "#FFA894", "flame", "Other"),
                ("Dry eyes/mouth", "#E8D4BF", "drop.triangle", "Other")
            ]

            for preset in defaults {
                let type = SymptomType(context: stackContext)

                type.id = UUID()
                type.name = preset.name
                type.color = preset.color
                type.iconName = preset.icon
                type.category = preset.category
                type.isDefault = true
                type.isStarred = false
                type.starOrder = 0
            }

            try? stackContext.save()
        }
    }
}
