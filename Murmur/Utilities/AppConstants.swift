import Foundation

/// Centralised configuration constants for the application.
enum AppConstants {
    /// HealthKit cache and lookback durations.
    enum HealthKit {
        /// Cache duration for HRV samples (30 minutes).
        static let hrvCacheDuration: TimeInterval = 30 * 60

        /// Cache duration for resting heart rate samples (60 minutes).
        static let restingHeartRateCacheDuration: TimeInterval = 60 * 60

        /// Cache duration for sleep data (6 hours).
        static let sleepCacheDuration: TimeInterval = 6 * 3600

        /// Cache duration for workout data (6 hours).
        static let workoutCacheDuration: TimeInterval = 6 * 3600

        /// Cache duration for menstrual cycle data (6 hours).
        static let cycleCacheDuration: TimeInterval = 6 * 3600

        /// Lookback period for quantity samples like HRV and heart rate (72 hours).
        static let quantitySampleLookback: TimeInterval = 72 * 3600

        /// Lookback period for sleep and workout data (24 hours).
        static let dailyMetricsLookback: TimeInterval = 24 * 3600

        /// Lookback period for menstrual cycle calculation (45 days).
        static let menstrualCycleLookback: TimeInterval = 45 * 24 * 3600

        /// Maximum number of HRV samples to fetch.
        static let hrvSampleLimit = 50

        /// Maximum number of resting heart rate samples to fetch.
        static let restingHeartRateSampleLimit = 10
    }
}
