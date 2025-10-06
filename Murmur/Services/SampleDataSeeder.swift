//
//  SampleDataSeeder.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 02/10/2025.
//

import CoreData
import Foundation
import os.log

struct SampleDataSeeder {
    private static let logger = Logger(subsystem: "app.murmur", category: "SampleData")
    private static let currentSeedVersion = 3 // Increment this when adding new default symptoms

    #if targetEnvironment(simulator)
    /// Generates realistic sample timeline entries for simulator testing
    static func generateSampleEntries(in context: NSManagedObjectContext) {
        context.perform {
            // Fetch existing symptom types
            let typeRequest: NSFetchRequest<SymptomType> = SymptomType.fetchRequest()
            guard let types = try? context.fetch(typeRequest), !types.isEmpty else {
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

            let positiveSymptoms = types.filter { symptom in
                symptom.category == "Positive wellbeing"
            }

            let occasionalSymptoms = types.filter { symptom in
                !commonSymptoms.contains(symptom) && symptom.category != "Positive wellbeing"
            }

            let pemSymptom = types.first { $0.name == "Post-Exertional Malaise (PEM)" }

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

            // Sample meals
            let breakfasts = ["Porridge with berries", "Toast and eggs", "Smoothie", "Granola and yoghurt", "Avocado toast"]
            let lunches = ["Salad with chicken", "Sandwich", "Soup and bread", "Leftover dinner", "Rice bowl"]
            let dinners = ["Pasta with vegetables", "Stir fry", "Grilled fish and salad", "Curry and rice", "Roast chicken"]
            let snacks = ["Apple", "Nuts", "Biscuits", "Yoghurt", "Cheese and crackers"]

            // Determine if cycle tracking should be enabled (80% chance)
            let hasCycleTracking = Double.random(in: 0...1) < 0.8
            var currentCycleDay = Int.random(in: 1...28) // Random starting point
            let cycleLength = Int.random(in: 26...32) // Realistic variation in cycle length

            // Track previous day's load for temporal correlations
            var previousDayTotalLoad = 0.0

            for dayOffset in 0..<60 {
                guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }

                // Determine daily pattern with priority ordering (no conflicts)
                let isPEMDay = previousDayTotalLoad > 15.0 // High load yesterday triggers PEM today
                let isFlareDay = !isPEMDay && (dayOffset % 13 == 0) // Periodic flares (avoiding PEM days)
                let isMenstrualDay = hasCycleTracking && currentCycleDay >= 1 && currentCycleDay <= 5
                let isRestDay = (dayOffset % 6 == 0) && !isPEMDay && !isFlareDay // Scheduled rest days
                let isBetterDay = !isPEMDay && !isFlareDay && !isMenstrualDay && (dayOffset % 9 == 8) // Some better days

                // Determine symptom count based on day type
                let baseSymptomCount: Int
                if isPEMDay {
                    baseSymptomCount = Int.random(in: 5...9)
                } else if isFlareDay {
                    baseSymptomCount = Int.random(in: 4...7)
                } else if isMenstrualDay {
                    baseSymptomCount = Int.random(in: 3...6)
                } else if isBetterDay {
                    baseSymptomCount = Int.random(in: 0...2)
                } else {
                    baseSymptomCount = Int.random(in: 2...4)
                }

                // Generate sleep event for previous night
                let sleepEvent = SleepEvent(context: context)
                sleepEvent.id = UUID()

                // Determine sleep quality and duration based on day type and previous activity
                let sleepQuality: Int16
                let sleepDuration: Double

                if isPEMDay || isFlareDay {
                    sleepQuality = Int16.random(in: 1...2) // Poor sleep
                    sleepDuration = Double.random(in: 4.0...6.0)
                } else if isMenstrualDay {
                    sleepQuality = Int16.random(in: 2...3)
                    sleepDuration = Double.random(in: 5.5...7.0)
                } else if isBetterDay {
                    sleepQuality = Int16.random(in: 4...5) // Good sleep
                    sleepDuration = Double.random(in: 7.5...9.0)
                } else {
                    sleepQuality = Int16.random(in: 2...4)
                    sleepDuration = Double.random(in: 6.0...8.0)
                }

                sleepEvent.quality = sleepQuality
                sleepEvent.hkSleepHours = NSNumber(value: sleepDuration)

                // Realistic bed and wake times
                let bedHour = Int.random(in: 21...23)
                let wakeHour = bedHour + Int(sleepDuration) - 24
                guard let bedTime = calendar.date(bySettingHour: bedHour, minute: Int.random(in: 0...59), second: 0, of: calendar.date(byAdding: .day, value: -1, to: date) ?? date),
                      let wakeTime = calendar.date(bySettingHour: wakeHour, minute: Int.random(in: 0...59), second: 0, of: date) else { continue }

                sleepEvent.bedTime = bedTime
                sleepEvent.wakeTime = wakeTime
                sleepEvent.createdAt = wakeTime
                sleepEvent.backdatedAt = wakeTime

                // Add sleep-related health metrics
                if isPEMDay || isFlareDay {
                    sleepEvent.hkHRV = NSNumber(value: Double.random(in: 15...30))
                    sleepEvent.hkRestingHR = NSNumber(value: Double.random(in: 72...85))
                } else if isBetterDay {
                    sleepEvent.hkHRV = NSNumber(value: Double.random(in: 50...70))
                    sleepEvent.hkRestingHR = NSNumber(value: Double.random(in: 52...62))
                } else {
                    sleepEvent.hkHRV = NSNumber(value: Double.random(in: 30...50))
                    sleepEvent.hkRestingHR = NSNumber(value: Double.random(in: 60...72))
                }

                // Link common sleep-related symptoms to sleep event
                if sleepQuality <= 2 {
                    let sleepSymptoms = types.filter { ["Insomnia", "Unrefreshing sleep", "Restless sleep"].contains($0.name ?? "") }
                    if let symptom = sleepSymptoms.randomElement() {
                        sleepEvent.addToSymptoms(symptom)
                    }
                }

                // Generate meal events (3 main meals + occasional snacks)
                let mealTimes: [(hour: Int, type: String, options: [String])] = [
                    (8, "Breakfast", breakfasts),
                    (13, "Lunch", lunches),
                    (19, "Dinner", dinners)
                ]

                for mealTime in mealTimes {
                    let meal = MealEvent(context: context)
                    meal.id = UUID()
                    meal.mealType = mealTime.type
                    meal.mealDescription = mealTime.options.randomElement()

                    guard let mealDate = calendar.date(bySettingHour: mealTime.hour, minute: Int.random(in: 0...59), second: 0, of: date) else { continue }
                    meal.createdAt = mealDate
                    meal.backdatedAt = mealDate

                    // Occasional notes about meals
                    if Double.random(in: 0...1) < 0.15 {
                        let mealNotes = [
                            "Felt nauseous after",
                            "Enjoyed this",
                            "Too much effort to prepare",
                            "Needed help with preparation",
                            "Simple and manageable"
                        ]
                        meal.note = mealNotes.randomElement()
                    }
                }

                // Occasional snacks
                if Double.random(in: 0...1) < 0.4 {
                    let snack = MealEvent(context: context)
                    snack.id = UUID()
                    snack.mealType = "Snack"
                    snack.mealDescription = snacks.randomElement()

                    guard let snackDate = calendar.date(bySettingHour: Int.random(in: 10...16), minute: Int.random(in: 0...59), second: 0, of: date) else { continue }
                    snack.createdAt = snackDate
                    snack.backdatedAt = snackDate
                }

                // Generate activities (fewer on PEM/flare/rest days)
                let activityCount: Int
                if isPEMDay {
                    activityCount = Int.random(in: 0...2) // Minimal activities on PEM days
                } else if isFlareDay || isRestDay {
                    activityCount = Int.random(in: 1...3) // Limited activities
                } else if isBetterDay {
                    activityCount = Int.random(in: 4...6) // More activities on better days
                } else {
                    activityCount = Int.random(in: 2...4) // Normal day
                }

                var dayTotalLoad = 0.0

                // Add activities for the day
                for activityIndex in 0..<activityCount {
                    let activity = ActivityEvent(context: context)
                    activity.id = UUID()

                    // Spread activities throughout the day (8am to 8pm)
                    let hourOffset = 8 + (activityIndex * (12 / max(activityCount, 1)))
                    let minuteOffset = Int.random(in: 0..<60)
                    guard let activityDate = calendar.date(bySettingHour: hourOffset, minute: minuteOffset, second: 0, of: date) else { continue }

                    activity.createdAt = activityDate
                    activity.backdatedAt = activityDate

                    // Select appropriate activity based on day type
                    let availableActivities: [(name: String, physical: Int16, cognitive: Int16, emotional: Int16, duration: Int)]
                    if isPEMDay || isFlareDay || isRestDay {
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

                    // Calculate load for this activity
                    let activityLoad = Double(selectedActivity.physical + selectedActivity.cognitive + selectedActivity.emotional) * (Double(selectedActivity.duration) / 60.0)
                    dayTotalLoad += activityLoad

                    // Add notes to some activities
                    if Double.random(in: 0...1) < 0.25 {
                        let activityNotes: [String]
                        if isPEMDay || isFlareDay {
                            activityNotes = [
                                "Had to take frequent breaks",
                                "Really struggled with this",
                                "Barely managed",
                                "Needed help"
                            ]
                        } else if isBetterDay {
                            activityNotes = [
                                "Felt good during this",
                                "Paced well",
                                "Manageable today",
                                "Felt capable"
                            ]
                        } else {
                            activityNotes = [
                                "Felt okay during this",
                                "Had to take breaks",
                                "Pushed through fatigue",
                                "Paced reasonably well",
                                "Needed rest after"
                            ]
                        }
                        activity.note = activityNotes.randomElement()
                    }
                }

                // Store load for next day's PEM calculation
                previousDayTotalLoad = dayTotalLoad

                // Add positive symptoms on better days
                if isBetterDay && !positiveSymptoms.isEmpty {
                    let positiveEntryCount = Int.random(in: 2...4)
                    for positiveIndex in 0..<positiveEntryCount {
                        let entry = SymptomEntry(context: context)
                        entry.id = UUID()

                        let hourOffset = positiveIndex * (12 / max(positiveEntryCount, 1)) + 9 // Morning to evening
                        let minuteOffset = Int.random(in: 0..<60)
                        guard let entryDate = calendar.date(byAdding: .hour, value: hourOffset, to: date),
                              let finalDate = calendar.date(byAdding: .minute, value: minuteOffset, to: entryDate) else { continue }

                        entry.createdAt = finalDate
                        entry.backdatedAt = finalDate
                        entry.symptomType = positiveSymptoms.randomElement()
                        entry.severity = Int16.random(in: 4...5) // High severity = high wellbeing
                    }
                }

                // Generate symptom entries
                for entryIndex in 0..<baseSymptomCount {
                    let entry = SymptomEntry(context: context)
                    entry.id = UUID()

                    // Spread entries throughout the day
                    let hourOffset = entryIndex * (24 / max(baseSymptomCount, 1))
                    let minuteOffset = Int.random(in: 0..<60)
                    guard let entryDate = calendar.date(byAdding: .hour, value: hourOffset, to: date),
                          let finalDate = calendar.date(byAdding: .minute, value: minuteOffset, to: entryDate) else { continue }

                    entry.createdAt = finalDate
                    entry.backdatedAt = finalDate

                    // Choose symptom type based on day type and frequency
                    if isPEMDay && entryIndex == 0 && pemSymptom != nil {
                        // First symptom on PEM day should be PEM
                        entry.symptomType = pemSymptom
                    } else if isMenstrualDay && entryIndex < 2 {
                        // Menstrual-specific symptoms
                        let menstrualSymptoms = types.filter { ["Heavy/painful periods", "Stomach pain", "Fatigue", "Headache"].contains($0.name ?? "") }
                        entry.symptomType = menstrualSymptoms.randomElement() ?? commonSymptoms.randomElement()
                    } else {
                        let useCommon = Double.random(in: 0...1) < 0.7
                        let symptomPool = useCommon ? commonSymptoms : occasionalSymptoms
                        entry.symptomType = symptomPool.randomElement() ?? types.randomElement()
                    }

                    // Set severity - worse on PEM/flare days
                    if isPEMDay {
                        entry.severity = Int16.random(in: 4...5)
                    } else if isFlareDay || isMenstrualDay {
                        entry.severity = Int16.random(in: 3...5)
                    } else if isBetterDay {
                        entry.severity = Int16.random(in: 1...2)
                    } else {
                        entry.severity = Int16.random(in: 2...4)
                    }

                    // Add notes to some entries
                    if Double.random(in: 0...1) < 0.35 {
                        let notes: [String]
                        if isPEMDay {
                            notes = [
                                "Worse after yesterday's activity",
                                "Crashed after overdoing it",
                                "Need complete rest",
                                "Payback from yesterday"
                            ]
                        } else if isFlareDay {
                            notes = [
                                "Triggered by stress",
                                "Affecting sleep",
                                "No clear trigger",
                                "Started suddenly",
                                "Very challenging"
                            ]
                        } else {
                            notes = [
                                "Improving gradually",
                                "Better with rest",
                                "Persistent today",
                                "Manageable",
                                "Comes and goes"
                            ]
                        }
                        entry.note = notes.randomElement()
                    }

                    // Add realistic health metrics (consistent for all entries on the day)
                    if entryIndex == 0 {
                        // HRV: lower on bad days, higher on good days
                        let baseHRV = isBetterDay ? 55.0 : (isPEMDay || isFlareDay ? 22.0 : 38.0)
                        entry.hkHRV = NSNumber(value: baseHRV + Double.random(in: -8...8))

                        // Resting HR: higher on PEM/flare days
                        let baseHR = isPEMDay || isFlareDay ? 78.0 : (isBetterDay ? 58.0 : 65.0)
                        entry.hkRestingHR = NSNumber(value: baseHR + Double.random(in: -4...4))

                        // Sleep hours from previous night
                        entry.hkSleepHours = NSNumber(value: sleepDuration)

                        // Workout: less on bad days, more on better days
                        if Double.random(in: 0...1) < 0.25 {
                            let baseWorkout = isPEMDay || isFlareDay ? 0.0 : (isBetterDay ? 25.0 : 10.0)
                            entry.hkWorkoutMinutes = NSNumber(value: max(0.0, baseWorkout + Double.random(in: -8...8)))
                        }

                        // Consistent cycle tracking across all entries on this day
                        if hasCycleTracking {
                            entry.hkCycleDay = NSNumber(value: currentCycleDay)

                            // Flow level during menstruation
                            if isMenstrualDay {
                                let flowLevels: [String]
                                let dayInPeriod = currentCycleDay
                                if dayInPeriod == 1 || dayInPeriod == 5 {
                                    flowLevels = ["light"]
                                } else if dayInPeriod == 2 || dayInPeriod == 3 {
                                    flowLevels = ["medium", "heavy"]
                                } else {
                                    flowLevels = ["light", "medium"]
                                }
                                entry.hkFlowLevel = flowLevels.randomElement()
                            }
                        }
                    }
                }

                // Update cycle day for next iteration (working backwards through time)
                if hasCycleTracking {
                    currentCycleDay -= 1
                    if currentCycleDay < 1 {
                        currentCycleDay = cycleLength
                    }
                }
            }

            try? context.save()
            logger.info("Generated sample timeline entries (symptoms, activities, sleep, and meals) for simulator")
        }
    }
    #endif

    static func seedIfNeeded(in context: NSManagedObjectContext, forceSeed: Bool = false) {
        context.perform {
            let lastSeedVersion = UserDefaults.standard.integer(forKey: UserDefaultsKeys.symptomSeedVersion)

            // Check if we need to seed or update (unless forceSeed is true for testing)
            guard forceSeed || lastSeedVersion < currentSeedVersion else { return }

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
                ("Dry eyes/mouth", "#E8D4BF", "drop.triangle", "Other"),

                // Reproductive & hormonal
                ("Irregular periods", "#E8A0BF", "calendar.badge.clock", "Reproductive & hormonal"),
                ("Acne", "#FFC1CC", "face.smiling", "Reproductive & hormonal"),
                ("Hirsutism (excess hair)", "#D4A5B8", "scissors", "Reproductive & hormonal"),
                ("Hair loss/thinning", "#C9B6D0", "comb", "Reproductive & hormonal"),
                ("Darkened skin patches", "#BFA6B8", "circle.lefthalf.filled", "Reproductive & hormonal"),
                ("Heavy/painful periods", "#D9A8C7", "calendar.badge.exclamationmark", "Reproductive & hormonal"),
                ("Hot flushes", "#FFB8A8", "flame.fill", "Reproductive & hormonal"),
                ("Night sweats", "#F5C6B8", "moon.dust", "Reproductive & hormonal"),
                ("Reduced libido", "#D4B8C9", "heart.slash.circle", "Reproductive & hormonal"),
                ("Erectile dysfunction", "#C9B8D4", "exclamationmark.circle", "Reproductive & hormonal"),
                ("Testicular pain", "#B8A8C9", "circle.circle", "Reproductive & hormonal"),
                ("Gynaecomastia (breast tissue)", "#E8C8D9", "figure.stand", "Reproductive & hormonal"),

                // Positive wellbeing
                ("Energy", "#A8E6A3", "bolt.fill", "Positive wellbeing"),
                ("Good concentration", "#A3D9E6", "brain.head.profile", "Positive wellbeing"),
                ("Mental clarity", "#B8D9F2", "sparkles", "Positive wellbeing"),
                ("Motivation", "#F2C6A3", "arrow.up.circle.fill", "Positive wellbeing"),
                ("Passion", "#FFB3BA", "heart.fill", "Positive wellbeing"),
                ("Joy", "#FFDFBA", "face.smiling.inverse", "Positive wellbeing"),
                ("Calm", "#C2E8D4", "leaf.fill", "Positive wellbeing"),
                ("Resilience", "#B8E6C9", "shield.fill", "Positive wellbeing"),
                ("Creativity", "#E6C2FF", "paintbrush.fill", "Positive wellbeing"),
                ("Social connection", "#FFD9B3", "person.2.fill", "Positive wellbeing")
            ]

            // Only add symptoms that don't already exist (by name)
            let fetchRequest: NSFetchRequest<SymptomType> = SymptomType.fetchRequest()
            let existingSymptoms = (try? context.fetch(fetchRequest)) ?? []
            let existingNames = Set(existingSymptoms.compactMap { $0.name })

            for preset in defaults {
                // Skip if this symptom already exists (preserves user modifications)
                guard !existingNames.contains(preset.name) else { continue }

                let type = SymptomType(context: context)
                type.id = UUID()
                type.name = preset.name
                type.color = preset.color
                type.iconName = preset.icon
                type.category = preset.category
                type.isDefault = true
                type.isStarred = false
                type.starOrder = 0
            }

            if let _ = try? context.save() {
                UserDefaults.standard.set(currentSeedVersion, forKey: UserDefaultsKeys.symptomSeedVersion)
                logger.info("Updated default symptoms to version \(currentSeedVersion)")
            }
        }
    }
}
