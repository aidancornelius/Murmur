//
//  SampleDataSeeder.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 02/10/2025.
//  Refactored: 10/10/2025 - Extracted random generation and HealthKit reads into separate services
//

import CoreData
import Foundation
import HealthKit
import os.log

/// Seeder focused on orchestrating Core Data writes for sample timeline data
/// Delegates to: SeededDataGenerator (random values), HealthKitSeedAdapter (HealthKit reads)
struct SampleDataSeeder {
    private static let logger = Logger(subsystem: "app.murmur", category: "SampleData")
    private static let currentSeedVersion = 4 // Increment this when adding new default symptoms

    #if targetEnvironment(simulator)

    /// Generates realistic sample timeline entries for simulator testing
    ///
    /// This method returns immediately and performs seeding asynchronously.
    /// It does not block the calling context. If you need to wait for completion,
    /// consider making this method async and removing the Task wrapper.
    /// - Parameters:
    ///   - context: The CoreData context to insert entries into
    ///   - dataProvider: Optional HealthKitDataProvider for dependency injection (defaults to RealHealthKitDataProvider)
    static func generateSampleEntries(in context: NSManagedObjectContext, dataProvider: HealthKitDataProvider? = nil) {
        Task {
            let now = Date()
            let calendar = Calendar.current

            // Pre-fetch HealthKit metrics for all days and cache them
            var metricsCache: [String: HealthMetrics] = [:]

            // Request HealthKit authorisation once before the loop (if not provided)
            let provider: HealthKitDataProvider?
            if let dataProvider = dataProvider {
                provider = dataProvider
            } else if HKHealthStore.isHealthDataAvailable() {
                let newProvider = RealHealthKitDataProvider()
                let readTypes: Set<HKObjectType> = Set([
                    HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
                    HKQuantityType.quantityType(forIdentifier: .restingHeartRate),
                    HKCategoryType.categoryType(forIdentifier: .sleepAnalysis),
                    HKObjectType.workoutType(),
                    HKCategoryType.categoryType(forIdentifier: .menstrualFlow)
                ].compactMap { $0 })

                do {
                    try await newProvider.requestAuthorization(toShare: [], read: readTypes)
                    provider = newProvider
                } catch {
                    logger.warning("HealthKit authorisation failed: \(error.localizedDescription)")
                    provider = nil
                }
            } else {
                provider = nil
            }

            for dayOffset in 0..<60 {
                guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }

                // Determine day type for this day (needed for fallback values)
                let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
                let seed = dayOfYear * 1000 + dayOffset

                // Simplified day type determination for metrics fetching
                let isPEMDay = (dayOffset > 0 && dayOffset % 7 == 1) // Simple pattern for now
                let isFlareDay = !isPEMDay && (dayOffset % 13 == 0)
                let isMenstrualDay = (dayOffset % 28) >= 1 && (dayOffset % 28) <= 5
                let isBetterDay = !isPEMDay && !isFlareDay && !isMenstrualDay && (dayOffset % 9 == 8)

                let dayType: DayType
                if isPEMDay {
                    dayType = .pem
                } else if isFlareDay {
                    dayType = .flare
                } else if isMenstrualDay {
                    dayType = .menstrual
                } else if isBetterDay {
                    dayType = .better
                } else {
                    dayType = .normal
                }

                let metrics = await HealthKitSeedAdapter.fetchHealthKitMetrics(for: date, dayType: dayType, seed: seed, dataProvider: provider)
                metricsCache[DateUtility.dayKey(for: date)] = metrics
            }

            await context.perform {
            // Fetch existing symptom types
            let typeRequest: NSFetchRequest<SymptomType> = SymptomType.fetchRequest()
            guard let types = try? context.fetch(typeRequest), !types.isEmpty else {
                logger.warning("No symptom types found - seed default types first")
                return
            }

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
                ("Video call with a friend", 1, 2, 3, 45),
                ("Light housework", 3, 2, 2, 30),
                ("Grocery shopping", 3, 3, 2, 40),
                ("Doctors appointment", 2, 3, 3, 60),
                // Higher exertion
                ("Work meeting", 2, 4, 3, 60),
                ("Deep work session", 1, 5, 2, 90),
                ("Social event", 3, 3, 4, 120),
                ("Cleaning house", 4, 2, 2, 45),
                ("Physio", 4, 2, 2, 45),
                ("Extended family visit", 2, 3, 4, 180)
            ]

            // Sample meals
            let breakfasts = ["Porridge with berries", "Toast and eggs", "Smoothie", "Granola and yoghurt", "Avocado toast"]
            let lunches = ["Quinoa salad", "Sandwich", "Soup and bread", "Leftover dinner", "Rice bowl"]
            let dinners = ["Pasta with vegetables", "Stir fry", "Burrito bowl", "Curry and rice", "Roast dinner"]
            let snacks = ["Apple", "Nuts", "Biscuits", "Yoghurt", "Cheese and crackers"]

            // Determine if cycle tracking should be enabled (80% chance)
            var cycleRng = SeededRandom(seed: 5000) // Fixed seed for cycle initialisation
            let hasCycleTracking = cycleRng.next() < 0.8
            var currentCycleDay = cycleRng.nextInt(in: 1...28) // Deterministic starting point
            let cycleLength = cycleRng.nextInt(in: 26...32) // Deterministic variation in cycle length

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
                var symptomCountRng = SeededRandom(seed: dayOffset * 3 + 1000)
                let baseSymptomCount: Int
                if isPEMDay {
                    baseSymptomCount = symptomCountRng.nextInt(in: 5...9)
                } else if isFlareDay {
                    baseSymptomCount = symptomCountRng.nextInt(in: 4...7)
                } else if isMenstrualDay {
                    baseSymptomCount = symptomCountRng.nextInt(in: 3...6)
                } else if isBetterDay {
                    baseSymptomCount = symptomCountRng.nextInt(in: 0...2)
                } else {
                    baseSymptomCount = symptomCountRng.nextInt(in: 2...4)
                }

                // Generate sleep event for previous night
                let sleepEvent = SleepEvent(context: context)
                sleepEvent.id = UUID()

                // Determine sleep quality and duration based on day type and previous activity
                var sleepRng = SeededRandom(seed: dayOffset * 7 + 100)
                let sleepQuality: Int16
                let sleepDuration: Double

                if isPEMDay || isFlareDay {
                    sleepQuality = Int16(sleepRng.nextInt(in: 1...2)) // Poor sleep
                    sleepDuration = sleepRng.next(in: 4.0...6.0)
                } else if isMenstrualDay {
                    sleepQuality = Int16(sleepRng.nextInt(in: 2...3))
                    sleepDuration = sleepRng.next(in: 5.5...7.0)
                } else if isBetterDay {
                    sleepQuality = Int16(sleepRng.nextInt(in: 4...5)) // Good sleep
                    sleepDuration = sleepRng.next(in: 7.5...9.0)
                } else {
                    sleepQuality = Int16(sleepRng.nextInt(in: 2...4))
                    sleepDuration = sleepRng.next(in: 6.0...8.0)
                }

                sleepEvent.quality = sleepQuality

                // Use cached HealthKit sleep hours if available, otherwise use generated duration
                let dateKey = DateUtility.dayKey(for: date)
                if let metrics = metricsCache[dateKey], let actualSleepHours = metrics.sleepHours {
                    sleepEvent.hkSleepHours = NSNumber(value: actualSleepHours)
                } else {
                    sleepEvent.hkSleepHours = NSNumber(value: sleepDuration)
                }

                // Realistic bed and wake times
                var bedTimeRng = SeededRandom(seed: dayOffset * 11 + 300)
                let bedHour = bedTimeRng.nextInt(in: 21...23)
                let bedMinute = bedTimeRng.nextInt(in: 0...59)
                let wakeMinute = bedTimeRng.nextInt(in: 0...59)
                let wakeHour = bedHour + Int(sleepDuration) - 24
                guard let bedTime = calendar.date(bySettingHour: bedHour, minute: bedMinute, second: 0, of: calendar.date(byAdding: .day, value: -1, to: date) ?? date),
                      let wakeTime = calendar.date(bySettingHour: wakeHour, minute: wakeMinute, second: 0, of: date) else { continue }

                sleepEvent.bedTime = bedTime
                sleepEvent.wakeTime = wakeTime
                sleepEvent.createdAt = wakeTime
                sleepEvent.backdatedAt = wakeTime

                // Add HRV and resting HR from cached HealthKit metrics
                if let metrics = metricsCache[dateKey] {
                    sleepEvent.hkHRV = NSNumber(value: metrics.hrv)
                    sleepEvent.hkRestingHR = NSNumber(value: metrics.restingHR)
                } else {
                    // Fallback if cache miss
                    let dayType: DayType = isPEMDay || isFlareDay ? .flare : (isBetterDay ? .better : .normal)
                    let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
                    let seed = dayOfYear * 1000 + dayOffset
                    sleepEvent.hkHRV = NSNumber(value: SeededDataGenerator.getFallbackHRV(for: dayType, seed: seed))
                    sleepEvent.hkRestingHR = NSNumber(value: SeededDataGenerator.getFallbackRestingHR(for: dayType, seed: seed))
                }

                // Link common sleep-related symptoms to sleep event
                if sleepQuality <= 2 {
                    let sleepSymptoms = types.filter { ["Insomnia", "Unrefreshing sleep", "Restless sleep"].contains($0.name ?? "") }
                    if !sleepSymptoms.isEmpty {
                        var sleepSymptomRng = SeededRandom(seed: dayOffset * 37 + 1100)
                        let symptomIdx = sleepSymptomRng.nextInt(in: 0...(sleepSymptoms.count - 1))
                        sleepEvent.addToSymptoms(sleepSymptoms[symptomIdx])
                    }
                }

                // Generate meal events (3 main meals + occasional snacks)
                let mealTimes: [(hour: Int, type: String, options: [String])] = [
                    (8, "Breakfast", breakfasts),
                    (13, "Lunch", lunches),
                    (19, "Dinner", dinners)
                ]

                var mealRng = SeededRandom(seed: dayOffset * 17 + 500)
                for (mealIndex, mealTime) in mealTimes.enumerated() {
                    let meal = MealEvent(context: context)
                    meal.id = UUID()
                    meal.mealType = mealTime.type
                    let optionIndex = mealRng.nextInt(in: 0...(mealTime.options.count - 1))
                    meal.mealDescription = mealTime.options[optionIndex]

                    let minute = mealRng.nextInt(in: 0...59)
                    guard let mealDate = calendar.date(bySettingHour: mealTime.hour, minute: minute, second: 0, of: date) else { continue }
                    meal.createdAt = mealDate
                    meal.backdatedAt = mealDate

                    // Occasional notes about meals
                    if mealRng.next() < 0.15 {
                        let mealNotes = [
                            "Felt nauseous after",
                            "Enjoyed this",
                            "Too much effort to prepare",
                            "Needed help with preparation",
                            "Simple and manageable"
                        ]
                        let noteIndex = mealRng.nextInt(in: 0...(mealNotes.count - 1))
                        meal.note = mealNotes[noteIndex]
                    }
                }

                // Occasional snacks
                var snackRng = SeededRandom(seed: dayOffset * 19 + 600)
                if snackRng.next() < 0.4 {
                    let snack = MealEvent(context: context)
                    snack.id = UUID()
                    snack.mealType = "Snack"
                    let snackIndex = snackRng.nextInt(in: 0...(snacks.count - 1))
                    snack.mealDescription = snacks[snackIndex]

                    let snackHour = snackRng.nextInt(in: 10...16)
                    let snackMinute = snackRng.nextInt(in: 0...59)
                    guard let snackDate = calendar.date(bySettingHour: snackHour, minute: snackMinute, second: 0, of: date) else { continue }
                    snack.createdAt = snackDate
                    snack.backdatedAt = snackDate
                }

                // Generate activities (fewer on PEM/flare/rest days)
                var activityCountRng = SeededRandom(seed: dayOffset * 23 + 700)
                let activityCount: Int
                if isPEMDay {
                    activityCount = activityCountRng.nextInt(in: 0...2) // Minimal activities on PEM days
                } else if isFlareDay || isRestDay {
                    activityCount = activityCountRng.nextInt(in: 1...3) // Limited activities
                } else if isBetterDay {
                    activityCount = activityCountRng.nextInt(in: 4...6) // More activities on better days
                } else {
                    activityCount = activityCountRng.nextInt(in: 2...4) // Normal day
                }

                var dayTotalLoad = 0.0

                // Add activities for the day
                var activityRng = SeededRandom(seed: dayOffset * 29 + 800)
                for activityIndex in 0..<activityCount {
                    let activity = ActivityEvent(context: context)
                    activity.id = UUID()

                    // Spread activities throughout the day (8am to 8pm)
                    let hourOffset = 8 + (activityIndex * (12 / max(activityCount, 1)))
                    let minuteOffset = activityRng.nextInt(in: 0...59)
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

                    let activityIdx = activityRng.nextInt(in: 0...(availableActivities.count - 1))
                    let selectedActivity = availableActivities[activityIdx]
                    activity.name = selectedActivity.name
                    activity.physicalExertion = selectedActivity.physical
                    activity.cognitiveExertion = selectedActivity.cognitive
                    activity.emotionalLoad = selectedActivity.emotional
                    activity.durationMinutes = NSNumber(value: selectedActivity.duration)

                    // Calculate load for this activity
                    let activityLoad = Double(selectedActivity.physical + selectedActivity.cognitive + selectedActivity.emotional) * (Double(selectedActivity.duration) / 60.0)
                    dayTotalLoad += activityLoad

                    // Add notes to some activities
                    if activityRng.next() < 0.25 {
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
                        let noteIdx = activityRng.nextInt(in: 0...(activityNotes.count - 1))
                        activity.note = activityNotes[noteIdx]
                    }
                }

                // Store load for next day's PEM calculation
                previousDayTotalLoad = dayTotalLoad

                // Add positive symptoms on better days
                if isBetterDay && !positiveSymptoms.isEmpty {
                    var positiveRng = SeededRandom(seed: dayOffset * 31 + 900)
                    let positiveEntryCount = positiveRng.nextInt(in: 2...4)
                    for positiveIndex in 0..<positiveEntryCount {
                        let entry = SymptomEntry(context: context)
                        entry.id = UUID()

                        let hourOffset = positiveIndex * (12 / max(positiveEntryCount, 1)) + 9 // Morning to evening
                        let minuteOffset = positiveRng.nextInt(in: 0...59)
                        guard let entryDate = calendar.date(byAdding: .hour, value: hourOffset, to: date),
                              let finalDate = calendar.date(byAdding: .minute, value: minuteOffset, to: entryDate) else { continue }

                        entry.createdAt = finalDate
                        entry.backdatedAt = finalDate
                        let positiveIdx = positiveRng.nextInt(in: 0...(positiveSymptoms.count - 1))
                        entry.symptomType = positiveSymptoms[positiveIdx]
                        entry.severity = Int16(positiveRng.nextInt(in: 4...5)) // High severity = high wellbeing
                    }
                }

                // Generate symptom entries
                var symptomEntryRng = SeededRandom(seed: dayOffset * 41 + 1200)
                for entryIndex in 0..<baseSymptomCount {
                    let entry = SymptomEntry(context: context)
                    entry.id = UUID()

                    // Spread entries throughout the day
                    let hourOffset = entryIndex * (24 / max(baseSymptomCount, 1))
                    let minuteOffset = symptomEntryRng.nextInt(in: 0...59)
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
                        if !menstrualSymptoms.isEmpty {
                            let symptomIdx = symptomEntryRng.nextInt(in: 0...(menstrualSymptoms.count - 1))
                            entry.symptomType = menstrualSymptoms[symptomIdx]
                        } else if !commonSymptoms.isEmpty {
                            let symptomIdx = symptomEntryRng.nextInt(in: 0...(commonSymptoms.count - 1))
                            entry.symptomType = commonSymptoms[symptomIdx]
                        }
                    } else {
                        let useCommon = symptomEntryRng.next() < 0.7
                        let symptomPool = useCommon ? commonSymptoms : occasionalSymptoms
                        if !symptomPool.isEmpty {
                            let symptomIdx = symptomEntryRng.nextInt(in: 0...(symptomPool.count - 1))
                            entry.symptomType = symptomPool[symptomIdx]
                        } else if !types.isEmpty {
                            let symptomIdx = symptomEntryRng.nextInt(in: 0...(types.count - 1))
                            entry.symptomType = types[symptomIdx]
                        }
                    }

                    // Set severity - worse on PEM/flare days
                    if isPEMDay {
                        entry.severity = Int16(symptomEntryRng.nextInt(in: 4...5))
                    } else if isFlareDay || isMenstrualDay {
                        entry.severity = Int16(symptomEntryRng.nextInt(in: 3...5))
                    } else if isBetterDay {
                        entry.severity = Int16(symptomEntryRng.nextInt(in: 1...2))
                    } else {
                        entry.severity = Int16(symptomEntryRng.nextInt(in: 2...4))
                    }

                    // Add notes to some entries
                    if symptomEntryRng.next() < 0.35 {
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
                        let noteIdx = symptomEntryRng.nextInt(in: 0...(notes.count - 1))
                        entry.note = notes[noteIdx]
                    }

                    // Add realistic health metrics (consistent for all entries on the day)
                    if entryIndex == 0 {
                        // Use cached HealthKit metrics from real data or fallback
                        if let metrics = metricsCache[dateKey] {
                            // Use all available HealthKit data
                            entry.hkHRV = NSNumber(value: metrics.hrv)
                            entry.hkRestingHR = NSNumber(value: metrics.restingHR)

                            // Use actual sleep hours if available
                            if let sleepHours = metrics.sleepHours {
                                entry.hkSleepHours = NSNumber(value: sleepHours)
                            } else {
                                // Fall back to sleep duration from sleep event
                                entry.hkSleepHours = NSNumber(value: sleepDuration)
                            }

                            // Use actual workout minutes if available
                            if let workoutMinutes = metrics.workoutMinutes {
                                entry.hkWorkoutMinutes = NSNumber(value: workoutMinutes)
                            } else {
                                // Fall back to deterministic generation
                                let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
                                let fallbackSeed = dayOfYear * 1000 + dayOffset
                                var workoutRng = SeededRandom(seed: dayOffset * 17 + 500)
                                if workoutRng.next() < 0.25 {
                                    let dayType: DayType = isPEMDay || isFlareDay ? .flare : (isBetterDay ? .better : .normal)
                                    entry.hkWorkoutMinutes = NSNumber(value: SeededDataGenerator.getFallbackWorkoutMinutes(for: dayType, seed: fallbackSeed))
                                }
                            }

                            // Use actual cycle day if available
                            if let cycleDay = metrics.cycleDay {
                                entry.hkCycleDay = NSNumber(value: cycleDay)
                            } else if hasCycleTracking {
                                entry.hkCycleDay = NSNumber(value: currentCycleDay)
                            }

                            // Use actual flow level if available
                            if let flowLevel = metrics.flowLevel {
                                entry.hkFlowLevel = flowLevel
                            } else if hasCycleTracking && isMenstrualDay {
                                // Fall back to deterministic generation
                                var flowRng = SeededRandom(seed: dayOffset * 19 + 600)
                                let dayInPeriod = currentCycleDay
                                let flowLevels: [String]
                                if dayInPeriod == 1 || dayInPeriod == 5 {
                                    flowLevels = ["light"]
                                } else if dayInPeriod == 2 || dayInPeriod == 3 {
                                    flowLevels = ["medium", "heavy"]
                                } else {
                                    flowLevels = ["light", "medium"]
                                }
                                let flowIndex = flowRng.nextInt(in: 0...(flowLevels.count - 1))
                                entry.hkFlowLevel = flowLevels[flowIndex]
                            }
                        } else {
                            // Fallback if cache miss - use deterministic seeds
                            let dayType: DayType = isPEMDay || isFlareDay ? .flare : (isBetterDay ? .better : .normal)
                            let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
                            let seed = dayOfYear * 1000 + dayOffset

                            entry.hkHRV = NSNumber(value: SeededDataGenerator.getFallbackHRV(for: dayType, seed: seed))
                            entry.hkRestingHR = NSNumber(value: SeededDataGenerator.getFallbackRestingHR(for: dayType, seed: seed))

                            // Sleep hours from previous night
                            entry.hkSleepHours = NSNumber(value: sleepDuration)

                            // Workout: less on bad days, more on better days
                            var workoutRng = SeededRandom(seed: dayOffset * 17 + 500)
                            if workoutRng.next() < 0.25 {
                                entry.hkWorkoutMinutes = NSNumber(value: SeededDataGenerator.getFallbackWorkoutMinutes(for: dayType, seed: seed))
                            }

                            // Consistent cycle tracking across all entries on this day
                            if hasCycleTracking {
                                entry.hkCycleDay = NSNumber(value: currentCycleDay)

                                // Flow level during menstruation
                                if isMenstrualDay {
                                    var flowRng = SeededRandom(seed: dayOffset * 19 + 600)
                                    let dayInPeriod = currentCycleDay
                                    let flowLevels: [String]
                                    if dayInPeriod == 1 || dayInPeriod == 5 {
                                        flowLevels = ["light"]
                                    } else if dayInPeriod == 2 || dayInPeriod == 3 {
                                        flowLevels = ["medium", "heavy"]
                                    } else {
                                        flowLevels = ["light", "medium"]
                                    }
                                    let flowIndex = flowRng.nextInt(in: 0...(flowLevels.count - 1))
                                    entry.hkFlowLevel = flowLevels[flowIndex]
                                }
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
    }
    /// Generates a large data set (1000+ entries) across 12 months for performance testing
    static func generateLargeDataSet(in context: NSManagedObjectContext) {
        context.perform {
            let typeRequest: NSFetchRequest<SymptomType> = SymptomType.fetchRequest()
            guard let types = try? context.fetch(typeRequest), !types.isEmpty else {
                logger.warning("No symptom types found - seed default types first")
                return
            }

            let now = Date()
            let calendar = Calendar.current

            // Generate 1200 entries across 365 days
            for dayOffset in 0..<365 {
                guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }

                var dayRng = SeededRandom(seed: dayOffset * 47 + 2000)
                let entriesPerDay = dayRng.nextInt(in: 3...4)

                for entryIndex in 0..<entriesPerDay {
                    let entry = SymptomEntry(context: context)
                    entry.id = UUID()

                    let hourOffset = entryIndex * (24 / max(entriesPerDay, 1))
                    let minuteOffset = dayRng.nextInt(in: 0...59)
                    guard let entryDate = calendar.date(byAdding: .hour, value: hourOffset, to: date),
                          let finalDate = calendar.date(byAdding: .minute, value: minuteOffset, to: entryDate) else { continue }

                    entry.createdAt = finalDate
                    entry.backdatedAt = finalDate
                    let typeIdx = dayRng.nextInt(in: 0...(types.count - 1))
                    entry.symptomType = types[typeIdx]
                    entry.severity = Int16(dayRng.nextInt(in: 1...5))

                    // Add notes to 20% of entries
                    if dayRng.next() < 0.2 {
                        entry.note = "Sample note for testing"
                    }
                }
            }

            try? context.save()
            logger.info("Generated large data set (1000+ entries)")
        }
    }

    /// Generates entries spanning 12+ months with moderate density
    static func generateLongHistory(in context: NSManagedObjectContext) {
        context.perform {
            let typeRequest: NSFetchRequest<SymptomType> = SymptomType.fetchRequest()
            guard let types = try? context.fetch(typeRequest), !types.isEmpty else {
                logger.warning("No symptom types found - seed default types first")
                return
            }

            let now = Date()
            let calendar = Calendar.current

            // Generate entries across 15 months (450 days)
            for dayOffset in 0..<450 {
                guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }

                var dayRng = SeededRandom(seed: dayOffset * 53 + 3000)
                let entriesPerDay = dayRng.nextInt(in: 1...3)

                for entryIndex in 0..<entriesPerDay {
                    let entry = SymptomEntry(context: context)
                    entry.id = UUID()

                    let hourOffset = entryIndex * (24 / max(entriesPerDay, 1))
                    let minuteOffset = dayRng.nextInt(in: 0...59)
                    guard let entryDate = calendar.date(byAdding: .hour, value: hourOffset, to: date),
                          let finalDate = calendar.date(byAdding: .minute, value: minuteOffset, to: entryDate) else { continue }

                    entry.createdAt = finalDate
                    entry.backdatedAt = finalDate
                    let typeIdx = dayRng.nextInt(in: 0...(types.count - 1))
                    entry.symptomType = types[typeIdx]
                    entry.severity = Int16(dayRng.nextInt(in: 1...5))
                }
            }

            try? context.save()
            logger.info("Generated long history (15 months)")
        }
    }

    /// Generates minimal data (10-20 entries) in the last 7 days
    static func generateMinimumData(in context: NSManagedObjectContext) {
        context.perform {
            let typeRequest: NSFetchRequest<SymptomType> = SymptomType.fetchRequest()
            guard let types = try? context.fetch(typeRequest), !types.isEmpty else {
                logger.warning("No symptom types found - seed default types first")
                return
            }

            let now = Date()
            let calendar = Calendar.current
            var rng = SeededRandom(seed: 4000)
            let entryCount = rng.nextInt(in: 10...20)

            for _ in 0..<entryCount {
                let entry = SymptomEntry(context: context)
                entry.id = UUID()

                // Distribute across 7 days
                let dayOffset = rng.nextInt(in: 0...6)
                let hourOffset = rng.nextInt(in: 0...23)
                let minuteOffset = rng.nextInt(in: 0...59)

                guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now),
                      let entryDate = calendar.date(bySettingHour: hourOffset, minute: minuteOffset, second: 0, of: date) else { continue }

                entry.createdAt = entryDate
                entry.backdatedAt = entryDate
                let typeIdx = rng.nextInt(in: 0...(types.count - 1))
                entry.symptomType = types[typeIdx]
                entry.severity = Int16(rng.nextInt(in: 1...5))
            }

            try? context.save()
            logger.info("Generated minimum data (10-20 entries)")
        }
    }

    /// Generates recent data only (15-30 entries) in the last 7 days
    static func generateRecentData(in context: NSManagedObjectContext) {
        context.perform {
            let typeRequest: NSFetchRequest<SymptomType> = SymptomType.fetchRequest()
            guard let types = try? context.fetch(typeRequest), !types.isEmpty else {
                logger.warning("No symptom types found - seed default types first")
                return
            }

            let now = Date()
            let calendar = Calendar.current

            // 2-4 entries per day for 7 days = 14-28 entries
            for dayOffset in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }

                var dayRng = SeededRandom(seed: dayOffset * 59 + 5000)
                let entriesPerDay = dayRng.nextInt(in: 2...4)

                for entryIndex in 0..<entriesPerDay {
                    let entry = SymptomEntry(context: context)
                    entry.id = UUID()

                    let hourOffset = entryIndex * (24 / max(entriesPerDay, 1))
                    let minuteOffset = dayRng.nextInt(in: 0...59)
                    guard let entryDate = calendar.date(byAdding: .hour, value: hourOffset, to: date),
                          let finalDate = calendar.date(byAdding: .minute, value: minuteOffset, to: entryDate) else { continue }

                    entry.createdAt = finalDate
                    entry.backdatedAt = finalDate
                    let typeIdx = dayRng.nextInt(in: 0...(types.count - 1))
                    entry.symptomType = types[typeIdx]
                    entry.severity = Int16(dayRng.nextInt(in: 1...5))
                }
            }

            try? context.save()
            logger.info("Generated recent data (15-30 entries)")
        }
    }
    #endif

    static func seedIfNeeded(in context: NSManagedObjectContext, forceSeed: Bool = false) {
        context.performAndWait {
            let lastSeedVersion = UserDefaults.standard.integer(forKey: UserDefaultsKeys.symptomSeedVersion)

            // Check if we need to seed or update (unless forceSeed is true for testing)
            guard forceSeed || lastSeedVersion < currentSeedVersion else { return }

            let defaults: [(name: String, color: String, icon: String, category: String)] = [
                // Energy
                ("Post-Exertional Malaise (PEM)", "#F5A3A3", "bolt.horizontal.circle", "Energy"),
                ("Fatigue", "#FFD966", "bolt.slash", "Energy"),
                ("Weakness", "#E8C89F", "figure.stand.line.dotted.figure.stand", "Energy"),
                ("Energy crashes", "#FFB84D", "bolt.slash.fill", "Energy"),
                ("Delayed fatigue", "#E8C89F", "hourglass", "Energy"),

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
                ("Pelvic pain", "#D9A8C7", "figure.stand.dress", "Pain"),
                ("Neck pain", "#B88AA6", "figure.stand", "Pain"),
                ("Foot/ankle pain", "#C99CB8", "shoe", "Pain"),
                ("Tension headache", "#E06666", "head.profile", "Pain"),

                // Cognitive
                ("Brain fog", "#6FA8DC", "brain", "Cognitive"),
                ("Cognitive difficulties", "#9BC4E8", "brain.head.profile", "Cognitive"),
                ("Difficulty concentrating", "#A8D5F2", "text.magnifyingglass", "Cognitive"),
                ("Memory problems", "#7FB3D5", "questionmark.circle", "Cognitive"),
                ("Word-finding difficulty", "#9BC4E8", "text.bubble", "Cognitive"),
                ("Slow processing", "#7FB3D5", "clock.arrow.circlepath", "Cognitive"),
                ("Decision fatigue", "#A8D5F2", "arrow.triangle.branch", "Cognitive"),

                // Sleep
                ("Unrefreshing sleep", "#B4A7D6", "moon.zzz", "Sleep"),
                ("Insomnia", "#C5B8D6", "moon.stars", "Sleep"),
                ("Nightmares", "#9D88B3", "moon.haze", "Sleep"),
                ("Restless sleep", "#B5A8C9", "bed.double", "Sleep"),
                ("Sleep apnoea symptoms", "#9D88B3", "wind.circle", "Sleep"),
                ("Early waking", "#C5B8D6", "sunrise", "Sleep"),

                // Neurological
                ("Dizziness", "#76C7C0", "arrow.triangle.2.circlepath", "Neurological"),
                ("Orthostatic intolerance", "#8DC6D2", "heart.circle", "Neurological"),
                ("Light/Sound sensitivity", "#FFB570", "waveform.path.ecg", "Neurological"),
                ("Numbness/Tingling", "#D4A5D9", "hand.raised.fingers.spread", "Neurological"),
                ("Tremors", "#C8B6D9", "hand.tap", "Neurological"),
                ("Coordination problems", "#D4BFA8", "figure.fall", "Neurological"),
                ("Vision problems", "#A8C5D9", "eye.trianglebadge.exclamationmark", "Neurological"),
                ("Ringing in ears (tinnitus)", "#D9C1A8", "ear", "Neurological"),
                ("Balance problems", "#8DC6D2", "figure.stairs", "Neurological"),
                ("Brain zaps", "#76C7C0", "bolt.fill", "Neurological"),
                ("Temperature sensitivity", "#FFB570", "thermometer.variable", "Neurological"),
                ("Touch sensitivity", "#D4A5D9", "hand.point.up.fill", "Neurological"),
                ("Restless legs", "#D4BFA8", "figure.walk.motion", "Neurological"),

                // Digestive
                ("Nausea", "#F4B183", "fork.knife", "Digestive"),
                ("Bloating", "#FFE4B8", "circle.hexagongrid", "Digestive"),
                ("Constipation", "#F5D4A8", "arrow.down.circle", "Digestive"),
                ("Diarrhea", "#FFDBB3", "arrow.down.to.line.compact", "Digestive"),
                ("IBS symptoms", "#FFE8C3", "exclamationmark.triangle", "Digestive"),
                ("Reflux/heartburn", "#F4B183", "flame", "Digestive"),
                ("Food sensitivities", "#FFE4B8", "exclamationmark.triangle.fill", "Digestive"),
                ("Loss of appetite", "#F5D4A8", "fork.knife.circle", "Digestive"),

                // Mental health
                ("Anxiety", "#B8D4E0", "cloud", "Mental health"),
                ("Depression", "#8FB4C9", "cloud.rain", "Mental health"),
                ("Panic", "#A5C8DB", "exclamationmark.bubble", "Mental health"),
                ("Flashbacks", "#C9DEE8", "arrow.counterclockwise", "Mental health"),
                ("Hypervigilance", "#D1E5F0", "eye", "Mental health"),
                ("Dissociation", "#B3D3E3", "eye.slash", "Mental health"),
                ("Mood swings", "#B8D4E0", "arrow.up.arrow.down.circle", "Mental health"),
                ("Irritability", "#A5C8DB", "exclamationmark.bubble.fill", "Mental health"),
                ("Brain fatigue", "#8FB4C9", "brain.head.profile.fill", "Mental health"),
                ("Emotional overwhelm", "#C9DEE8", "cloud.rain.fill", "Mental health"),

                // Respiratory & cardiovascular
                ("Palpitations", "#F39C9C", "waveform.path.ecg.rectangle", "Respiratory & cardiovascular"),
                ("Shortness of breath", "#A6D9E8", "lungs", "Respiratory & cardiovascular"),
                ("Sore throat", "#FF9AA2", "mouth", "Respiratory & cardiovascular"),
                ("Rapid heartbeat", "#F39C9C", "heart.circle.fill", "Respiratory & cardiovascular"),
                ("Chest tightness", "#E08E8E", "square.compress", "Respiratory & cardiovascular"),
                ("Exercise intolerance", "#FF9AA2", "figure.run.circle", "Respiratory & cardiovascular"),
                ("Cough", "#FFB8C6", "wind", "Respiratory & cardiovascular"),

                // Other
                ("Flu-like symptoms", "#FFB8C6", "cross.case", "Other"),
                ("Swollen lymph nodes", "#FFC3A0", "heart.text.square", "Other"),
                ("Temperature dysregulation", "#FFCBA4", "thermometer.medium", "Other"),
                ("Inflammation", "#FFA894", "flame", "Other"),
                ("Dry eyes/mouth", "#E8D4BF", "drop.triangle", "Other"),
                ("Chemical sensitivity", "#FFCBA4", "nose", "Other"),
                ("Light-headedness", "#FFA894", "sparkles.square.filled.on.square", "Other"),
                ("Muscle twitches", "#E8D4BF", "waveform.path", "Other"),

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
                ("PMS symptoms", "#E8A0BF", "calendar.circle", "Reproductive & hormonal"),
                ("Fertility concerns", "#D4A5B8", "heart.circle", "Reproductive & hormonal"),
                ("Low testosterone symptoms", "#B8A8C9", "figure.stand.line.dotted.figure.stand", "Reproductive & hormonal"),

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
                ("Social connection", "#FFD9B3", "person.2.fill", "Positive wellbeing"),
                ("Physical strength", "#B8E6C9", "figure.strengthtraining.traditional", "Positive wellbeing"),
                ("Clear thinking", "#A3D9E6", "lightbulb.fill", "Positive wellbeing"),
                ("Hope", "#C2E8D4", "sunrise.fill", "Positive wellbeing"),
                ("Gratitude", "#FFD9B3", "heart.text.square.fill", "Positive wellbeing"),
                ("Restful sleep", "#B4A7D6", "bed.double.fill", "Positive wellbeing"),
                ("Connected to Country", "#C2E8D4", "leaf.circle.fill", "Positive wellbeing")
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
