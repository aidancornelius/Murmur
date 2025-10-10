//
//  SampleDataSeeder.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 02/10/2025.
//

@preconcurrency import CoreData
import Foundation
import HealthKit
import os.log

/// Deterministic pseudo-random number generator using Linear Congruential Generator (LCG)
/// Ensures reproducible random values when seeded consistently
private struct SeededRandom {
    private var state: UInt64

    init(seed: Int) {
        // Use non-zero seed (LCG requires non-zero state)
        self.state = UInt64(max(1, seed))
    }

    /// Generate next random value in [0, 1) range
    mutating func next() -> Double {
        // LCG parameters from Numerical Recipes
        state = state &* 1664525 &+ 1013904223
        return Double(state % 1000000) / 1000000.0
    }

    /// Generate random value in specified Double range
    mutating func next(in range: ClosedRange<Double>) -> Double {
        let normalized = next()
        return range.lowerBound + normalized * (range.upperBound - range.lowerBound)
    }

    /// Generate random integer in specified range
    mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        let normalized = next()
        let rangeSize = Double(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(normalized * rangeSize)
    }
}

/// Helper struct to hold health metrics queried from HealthKit
private struct HealthMetrics {
    let hrv: Double
    let restingHR: Double
    let sleepHours: Double?
    let workoutMinutes: Double?
    let cycleDay: Int?
    let flowLevel: String?
}

struct SampleDataSeeder {
    private static let logger = Logger(subsystem: "app.murmur", category: "SampleData")
    private static let currentSeedVersion = 4 // Increment this when adding new default symptoms

    #if targetEnvironment(simulator)

    // MARK: - HealthKit Integration

    /// Fetch health metrics from HealthKit for a specific date
    /// - Parameters:
    ///   - date: The date to query metrics for
    ///   - dayType: The type of day (for fallback generation)
    ///   - seed: Deterministic seed for fallback values
    ///   - healthStore: Optional pre-authorized HKHealthStore (to avoid redundant authorization)
    /// - Returns: HealthMetrics containing queried or fallback values
    private static func fetchHealthKitMetrics(for date: Date, dayType: DayType, seed: Int, healthStore: HKHealthStore? = nil) async -> HealthMetrics {
        // Use provided healthStore or create and authorize a new one
        let store: HKHealthStore
        if let healthStore = healthStore {
            store = healthStore
        } else {
            guard HKHealthStore.isHealthDataAvailable() else {
                return HealthMetrics(
                    hrv: getFallbackHRV(for: dayType, seed: seed),
                    restingHR: getFallbackRestingHR(for: dayType, seed: seed),
                    sleepHours: nil,
                    workoutMinutes: nil,
                    cycleDay: nil,
                    flowLevel: nil
                )
            }

            let newStore = HKHealthStore()
            let readTypes: Set<HKObjectType> = Set([
                HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
                HKQuantityType.quantityType(forIdentifier: .restingHeartRate),
                HKCategoryType.categoryType(forIdentifier: .sleepAnalysis),
                HKObjectType.workoutType(),
                HKCategoryType.categoryType(forIdentifier: .menstrualFlow)
            ].compactMap { $0 })

            do {
                try await newStore.requestAuthorization(toShare: [], read: readTypes)
                store = newStore
            } catch {
                logger.warning("HealthKit authorization failed: \(error.localizedDescription)")
                return HealthMetrics(
                    hrv: getFallbackHRV(for: dayType, seed: seed),
                    restingHR: getFallbackRestingHR(for: dayType, seed: seed),
                    sleepHours: nil,
                    workoutMinutes: nil,
                    cycleDay: nil,
                    flowLevel: nil
                )
            }
        }

        // Shared date range for all queries
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date

        // Query HRV
        let hrv: Double? = try? await withCheckedThrowingContinuation { continuation in
            let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

            let query = HKStatisticsQuery(quantityType: hrvType, quantitySamplePredicate: predicate, options: .discreteAverage) { _, statistics, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let value = statistics?.averageQuantity()?.doubleValue(for: HKUnit.secondUnit(with: .milli))
                continuation.resume(returning: value)
            }

            store.execute(query)
        }

        // Query resting heart rate
        let restingHR: Double? = try? await withCheckedThrowingContinuation { continuation in
            let restingHRType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

            let query = HKStatisticsQuery(quantityType: restingHRType, quantitySamplePredicate: predicate, options: .discreteAverage) { _, statistics, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let value = statistics?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                continuation.resume(returning: value)
            }

            store.execute(query)
        }

        // Query sleep hours
        let sleepHours: Double? = try? await withCheckedThrowingContinuation { continuation in
            let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let categorySamples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: nil)
                    return
                }

                // Filter for asleep states
                let asleepSamples = categorySamples.filter { sample in
                    if #available(iOS 16.0, *) {
                        return [
                            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                        ].contains(sample.value)
                    } else {
                        return sample.value == HKCategoryValueSleepAnalysis.asleep.rawValue
                    }
                }

                // Sum total sleep duration in hours
                let totalSeconds = asleepSamples.reduce(0.0) { total, sample in
                    total + sample.endDate.timeIntervalSince(sample.startDate)
                }

                let hours = totalSeconds / 3600.0
                continuation.resume(returning: hours > 0 ? hours : nil)
            }

            store.execute(query)
        }

        // Query workout minutes
        let workoutMinutes: Double? = try? await withCheckedThrowingContinuation { continuation in
            let workoutType = HKObjectType.workoutType()
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

            let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let workouts = samples as? [HKWorkout] else {
                    continuation.resume(returning: nil)
                    return
                }

                // Sum total workout duration in minutes
                let totalSeconds = workouts.reduce(0.0) { total, workout in
                    total + workout.duration
                }

                let minutes = totalSeconds / 60.0
                continuation.resume(returning: minutes > 0 ? minutes : nil)
            }

            store.execute(query)
        }

        // Query cycle day (days since last period start)
        let cycleDay: Int? = try? await withCheckedThrowingContinuation { continuation in
            let flowType = HKCategoryType.categoryType(forIdentifier: .menstrualFlow)!

            // Look back up to 60 days for last period start
            let lookbackDate = calendar.date(byAdding: .day, value: -60, to: date) ?? date
            let predicate = HKQuery.predicateForSamples(withStart: lookbackDate, end: date, options: .strictStartDate)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

            let query = HKSampleQuery(sampleType: flowType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let flowSamples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: nil)
                    return
                }

                // Find most recent period start (flow > none)
                let periodStarts = flowSamples.filter { sample in
                    if #available(iOS 18.0, *) {
                        return sample.value > HKCategoryValueVaginalBleeding.none.rawValue
                    } else {
                        return sample.value > HKCategoryValueMenstrualFlow.none.rawValue
                    }
                }

                guard let lastPeriodStart = periodStarts.first else {
                    continuation.resume(returning: nil)
                    return
                }

                // Calculate days since period start
                let daysSince = calendar.dateComponents([.day], from: lastPeriodStart.startDate, to: date).day
                continuation.resume(returning: daysSince)
            }

            store.execute(query)
        }

        // Query flow level for the day
        let flowLevel: String? = try? await withCheckedThrowingContinuation { continuation in
            let flowType = HKCategoryType.categoryType(forIdentifier: .menstrualFlow)!
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

            let query = HKSampleQuery(sampleType: flowType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let flowSamples = samples as? [HKCategorySample], !flowSamples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }

                // Find highest flow value for the day
                let maxFlow: Int
                let flowString: String

                if #available(iOS 18.0, *) {
                    maxFlow = flowSamples.map(\.value).max() ?? HKCategoryValueVaginalBleeding.none.rawValue
                    switch maxFlow {
                    case HKCategoryValueVaginalBleeding.none.rawValue:
                        flowString = "none"
                    case HKCategoryValueVaginalBleeding.light.rawValue:
                        flowString = "light"
                    case HKCategoryValueVaginalBleeding.medium.rawValue:
                        flowString = "medium"
                    case HKCategoryValueVaginalBleeding.heavy.rawValue:
                        flowString = "heavy"
                    default:
                        flowString = "unspecified"
                    }
                } else {
                    maxFlow = flowSamples.map(\.value).max() ?? HKCategoryValueMenstrualFlow.none.rawValue
                    switch maxFlow {
                    case HKCategoryValueMenstrualFlow.none.rawValue:
                        flowString = "none"
                    case HKCategoryValueMenstrualFlow.light.rawValue:
                        flowString = "light"
                    case HKCategoryValueMenstrualFlow.medium.rawValue:
                        flowString = "medium"
                    case HKCategoryValueMenstrualFlow.heavy.rawValue:
                        flowString = "heavy"
                    default:
                        flowString = "unspecified"
                    }
                }

                continuation.resume(returning: flowString)
            }

            store.execute(query)
        }

        // Return metrics with fallbacks for nil values
        return HealthMetrics(
            hrv: hrv ?? getFallbackHRV(for: dayType, seed: seed),
            restingHR: restingHR ?? getFallbackRestingHR(for: dayType, seed: seed),
            sleepHours: sleepHours,
            workoutMinutes: workoutMinutes,
            cycleDay: cycleDay,
            flowLevel: flowLevel
        )
    }

    /// Day type classification for generating appropriate fallback values
    private enum DayType {
        case pem
        case flare
        case menstrual
        case rest
        case better
        case normal
    }

    /// Generate fallback HRV value based on day type
    private static func getFallbackHRV(for dayType: DayType, seed: Int) -> Double {
        var rng = SeededRandom(seed: seed)

        switch dayType {
        case .pem, .flare:
            return 22.0 + rng.next(in: -5...5)
        case .better:
            return 55.0 + rng.next(in: -8...8)
        case .normal, .menstrual, .rest:
            return 38.0 + rng.next(in: -8...8)
        }
    }

    /// Generate fallback resting heart rate based on day type
    private static func getFallbackRestingHR(for dayType: DayType, seed: Int) -> Double {
        var rng = SeededRandom(seed: seed + 1) // Different offset for variety

        switch dayType {
        case .pem, .flare:
            return 78.0 + rng.next(in: -4...4)
        case .better:
            return 58.0 + rng.next(in: -4...4)
        case .normal, .menstrual, .rest:
            return 65.0 + rng.next(in: -4...4)
        }
    }

    /// Generate fallback sleep hours based on day type
    private static func getFallbackSleepHours(for dayType: DayType, seed: Int) -> Double {
        var rng = SeededRandom(seed: seed + 2)

        switch dayType {
        case .pem, .flare:
            return 5.5 + rng.next(in: -1.5...1.5)
        case .menstrual, .rest:
            return 6.5 + rng.next(in: -1.0...1.0)
        case .better:
            return 8.0 + rng.next(in: -0.5...0.5)
        case .normal:
            return 7.5 + rng.next(in: -1.0...1.0)
        }
    }

    /// Generate fallback workout minutes based on day type
    private static func getFallbackWorkoutMinutes(for dayType: DayType, seed: Int) -> Double {
        var rng = SeededRandom(seed: seed + 3)

        switch dayType {
        case .pem, .flare:
            return rng.next(in: 0...10)
        case .menstrual, .rest:
            return rng.next(in: 5...20)
        case .better:
            return rng.next(in: 25...50)
        case .normal:
            return rng.next(in: 15...35)
        }
    }

    /// Helper function to generate consistent day keys for caching
    private static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// Generates realistic sample timeline entries for simulator testing
    ///
    /// This method returns immediately and performs seeding asynchronously.
    /// It does not block the calling context. If you need to wait for completion,
    /// consider making this method async and removing the Task wrapper.
    static func generateSampleEntries(in context: NSManagedObjectContext) {
        Task {
            let now = Date()
            let calendar = Calendar.current

            // Pre-fetch HealthKit metrics for all days and cache them
            var metricsCache: [String: HealthMetrics] = [:]

            // Request HealthKit authorization once before the loop
            let healthStore: HKHealthStore?
            if HKHealthStore.isHealthDataAvailable() {
                let store = HKHealthStore()
                let readTypes: Set<HKObjectType> = Set([
                    HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
                    HKQuantityType.quantityType(forIdentifier: .restingHeartRate),
                    HKCategoryType.categoryType(forIdentifier: .sleepAnalysis),
                    HKObjectType.workoutType(),
                    HKCategoryType.categoryType(forIdentifier: .menstrualFlow)
                ].compactMap { $0 })

                do {
                    try await store.requestAuthorization(toShare: [], read: readTypes)
                    healthStore = store
                } catch {
                    logger.warning("HealthKit authorization failed: \(error.localizedDescription)")
                    healthStore = nil
                }
            } else {
                healthStore = nil
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

                let metrics = await fetchHealthKitMetrics(for: date, dayType: dayType, seed: seed, healthStore: healthStore)
                metricsCache[dayKey(for: date)] = metrics
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
            var cycleRng = SeededRandom(seed: 5000) // Fixed seed for cycle initialization
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
                let dateKey = dayKey(for: date)
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
                    var healthRng = SeededRandom(seed: dayOffset * 13 + 400)
                    if isPEMDay || isFlareDay {
                        sleepEvent.hkHRV = NSNumber(value: healthRng.next(in: 15...30))
                        sleepEvent.hkRestingHR = NSNumber(value: healthRng.next(in: 72...85))
                    } else if isBetterDay {
                        sleepEvent.hkHRV = NSNumber(value: healthRng.next(in: 50...70))
                        sleepEvent.hkRestingHR = NSNumber(value: healthRng.next(in: 52...62))
                    } else {
                        sleepEvent.hkHRV = NSNumber(value: healthRng.next(in: 30...50))
                        sleepEvent.hkRestingHR = NSNumber(value: healthRng.next(in: 60...72))
                    }
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
                                var workoutRng = SeededRandom(seed: dayOffset * 17 + 500)
                                if workoutRng.next() < 0.25 {
                                    let baseWorkout = isPEMDay || isFlareDay ? 0.0 : (isBetterDay ? 25.0 : 10.0)
                                    entry.hkWorkoutMinutes = NSNumber(value: max(0.0, baseWorkout + workoutRng.next(in: -8...8)))
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
                            var healthRng = SeededRandom(seed: dayOffset * 13 + 400)
                            let baseHRV = isBetterDay ? 55.0 : (isPEMDay || isFlareDay ? 22.0 : 38.0)
                            entry.hkHRV = NSNumber(value: baseHRV + healthRng.next(in: -8...8))

                            let baseHR = isPEMDay || isFlareDay ? 78.0 : (isBetterDay ? 58.0 : 65.0)
                            entry.hkRestingHR = NSNumber(value: baseHR + healthRng.next(in: -4...4))

                            // Sleep hours from previous night
                            entry.hkSleepHours = NSNumber(value: sleepDuration)

                            // Workout: less on bad days, more on better days
                            var workoutRng = SeededRandom(seed: dayOffset * 17 + 500)
                            if workoutRng.next() < 0.25 {
                                let baseWorkout = isPEMDay || isFlareDay ? 0.0 : (isBetterDay ? 25.0 : 10.0)
                                entry.hkWorkoutMinutes = NSNumber(value: max(0.0, baseWorkout + workoutRng.next(in: -8...8)))
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

            for entryIndex in 0..<entryCount {
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
