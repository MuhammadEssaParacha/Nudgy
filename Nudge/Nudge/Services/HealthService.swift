//
//  HealthService.swift
//  Nudge
//
//  HealthKit integration for writing mindful session data
//  when the user completes a focus timer, and reading step count
//  for energy-level suggestions.
//
//  Privacy: HealthKit access is opt-in (Settings toggle).
//  Writes: Mindful Minutes (from focus timer completion).
//  Reads: Step Count (for energy-level suggestions).
//

import HealthKit
import SwiftUI
import os

@MainActor @Observable
final class HealthService {
    
    static let shared = HealthService()
    
    // MARK: - State
    
    /// Whether HealthKit is available on this device
    let isAvailable = HKHealthStore.isHealthDataAvailable()
    
    /// Whether the user has granted HealthKit permission
    private(set) var isAuthorized = false
    
    /// Whether HealthKit features are enabled by the user (Settings toggle)
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "healthKitEnabled") }
        set {
            UserDefaults.standard.set(newValue, forKey: "healthKitEnabled")
            if newValue && !isAuthorized {
                Task { await requestAuthorization() }
            }
        }
    }
    
    /// Today's step count (refreshed periodically)
    private(set) var todayStepCount: Int = 0
    
    /// Suggested energy level based on step count and time of day
    var suggestedEnergyLevel: EnergyLevel? {
        let hour = Calendar.current.component(.hour, from: Date())
        
        // Morning (before noon): high energy if active
        if hour < 12 {
            if todayStepCount > 2000 { return .high }
            return .medium
        }
        // Afternoon (12-5pm): energy dips
        if hour < 17 {
            if todayStepCount > 5000 { return .medium }
            return .low
        }
        // Evening: winding down
        return .low
    }
    
    // MARK: - Private
    
    private let store = HKHealthStore()
    private let log = Logger(subsystem: "com.tarsitgroup.nudge", category: "Health")
    
    /// Types we want to read
    private var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()
        if let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            types.insert(stepType)
        }
        return types
    }
    
    /// Types we want to write
    private var writeTypes: Set<HKSampleType> {
        var types = Set<HKSampleType>()
        if let mindfulType = HKCategoryType.categoryType(forIdentifier: .mindfulSession) {
            types.insert(mindfulType)
        }
        return types
    }
    
    // MARK: - Init
    
    private init() {}
    
    // MARK: - Authorization
    
    /// Request HealthKit authorization for mindful sessions and step count.
    func requestAuthorization() async {
        guard isAvailable else {
            log.warning("HealthKit not available on this device")
            return
        }
        
        do {
            try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
            isAuthorized = true
            log.info("HealthKit authorization granted")
            
            // Fetch initial step count
            await refreshStepCount()
        } catch {
            log.error("HealthKit authorization failed: \(error)")
            isAuthorized = false
        }
    }
    
    // MARK: - Write: Mindful Sessions
    
    /// Record a mindful session (focus timer completion) in HealthKit.
    /// - Parameters:
    ///   - startDate: When the focus timer started
    ///   - endDate: When the focus timer ended
    ///   - taskContent: Description of what the user focused on (stored as metadata)
    func recordMindfulSession(
        startDate: Date,
        endDate: Date,
        taskContent: String? = nil
    ) async {
        guard isEnabled, isAuthorized else {
            log.debug("Skipping mindful session — not enabled or authorized")
            return
        }
        
        guard let mindfulType = HKCategoryType.categoryType(forIdentifier: .mindfulSession) else {
            log.error("Mindful session type not available")
            return
        }
        
        var metadata: [String: Any] = [
            HKMetadataKeyExternalUUID: UUID().uuidString,
            "com.tarsitgroup.nudge.source": "focus_timer"
        ]
        if let taskContent {
            metadata["com.tarsitgroup.nudge.task"] = String(taskContent.prefix(100))
        }
        
        let sample = HKCategorySample(
            type: mindfulType,
            value: HKCategoryValue.notApplicable.rawValue,
            start: startDate,
            end: endDate,
            metadata: metadata
        )
        
        do {
            try await store.save(sample)
            let minutes = Int(endDate.timeIntervalSince(startDate) / 60)
            log.info("Recorded \(minutes)-minute mindful session to HealthKit")
        } catch {
            log.error("Failed to save mindful session: \(error)")
        }
    }
    
    // MARK: - Read: Step Count
    
    /// Refresh today's step count from HealthKit.
    func refreshStepCount() async {
        guard isEnabled, isAuthorized else { return }
        
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: Date(),
            options: .strictStartDate
        )
        
        do {
            let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Double, Error>) in
                let query = HKStatisticsQuery(
                    quantityType: stepType,
                    quantitySamplePredicate: predicate,
                    options: .cumulativeSum
                ) { _, result, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    let sum = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                    continuation.resume(returning: sum)
                }
                self.store.execute(query)
            }
            todayStepCount = Int(result)
            log.debug("Today's step count: \(self.todayStepCount)")
        } catch {
            log.error("Failed to fetch step count: \(error)")
        }
    }
    
    /// Get total mindful minutes for today.
    func todayMindfulMinutes() async -> Int {
        guard isEnabled, isAuthorized else { return 0 }
        
        guard let mindfulType = HKCategoryType.categoryType(forIdentifier: .mindfulSession) else { return 0 }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: Date(),
            options: .strictStartDate
        )
        
        do {
            let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int, Error>) in
                let query = HKSampleQuery(
                    sampleType: mindfulType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: nil
                ) { _, samples, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    let totalSeconds = (samples ?? []).reduce(0.0) { sum, sample in
                        sum + sample.endDate.timeIntervalSince(sample.startDate)
                    }
                    continuation.resume(returning: Int(totalSeconds / 60))
                }
                self.store.execute(query)
            }
            return result
        } catch {
            log.error("Failed to fetch mindful minutes: \(error)")
            return 0
        }
    }
}
