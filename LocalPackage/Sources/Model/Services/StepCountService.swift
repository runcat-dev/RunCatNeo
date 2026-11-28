/*
 StepCountService.swift
 Model

 Created by Takuto Nakamura on 2026/11/28.
 Copyright 2026 Kyome22 (Takuto Nakamura)

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import DataSource
import Foundation

/// Counts the steps the runner takes and keeps one record per day.
///
/// One step is one full animation cycle of the runner: the keyframe animation loops once per
/// `frameCount / 2` seconds at animation speed 1.0, and the speed is proportional to the CPU
/// usage, so the number of steps between two samples is `speed * 2 / frameCount * elapsedTime`.
/// The counter integrates that over the samples the system metrics service receives and persists
/// the daily totals under Application Support.
struct StepCountService {
    /// Animation cycles the runner completes per second while the animation speed is 1.0.
    static let cyclesPerSecondAtUnitSpeed = 2.0

    /// Sampling gaps longer than this are clamped, so that sleep/wake or a stalled thread does not
    /// add a huge burst of steps.
    static let maximumSampleInterval: TimeInterval = 60.0

    /// How often the records are written to disk at most.
    static let saveInterval: TimeInterval = 30.0

    /// The window the "steps in the last minute" figure is calculated over.
    static let recentWindowSeconds: TimeInterval = 60.0

    /// How many days of records are kept.
    static let retentionDays = 366

    private let appStateClient: AppStateClient
    private let dateClient: DateClient
    private let userDefaultsRepository: UserDefaultsRepository
    private let applicationSupportRepository: ApplicationSupportRepository

    init(_ appDependencies: AppDependencies) {
        self.appStateClient = appDependencies.appStateClient
        self.dateClient = appDependencies.dateClient
        self.userDefaultsRepository = .init(appDependencies.userDefaultsClient)
        self.applicationSupportRepository = .init(
            appDependencies.dataClient,
            appDependencies.fileManagerClient
        )
    }

    /// Loads the persisted records and publishes the statistics before the first sample arrives.
    func bootstrap() {
        let now = dateClient.now()
        let todayKey = Self.dayKey(for: now)
        let records = Self.pruned(applicationSupportRepository.loadStepRecords())
        let ledger = StepLedger(records: records, lastSampleDate: now, lastSavedDate: now)
        appStateClient.withLock { state in
            state.stepLedger = ledger
        }
        if userDefaultsRepository.isStepCounterEnabled {
            appStateClient.send(\.stepStatistics, ledger.statistics(todayKey: todayKey))
        } else {
            appStateClient.send(\.stepStatistics, .empty)
        }
    }

    /// Adds the steps taken since the previous sample.
    func accumulate(speed: Float, frameCount: Int, at date: Date) {
        guard userDefaultsRepository.isStepCounterEnabled else {
            pause(at: date)
            return
        }
        let todayKey = Self.dayKey(for: date)
        let result: (statistics: StepStatistics, recordsToSave: [StepRecord]?) = appStateClient.withLock { state in
            var ledger = state.stepLedger
            let interval = Self.interval(from: ledger.lastSampleDate, to: date)
            ledger.lastSampleDate = date
            ledger.pendingFraction += Self.steps(speed: speed, frameCount: frameCount, interval: interval)
            let steps = Int(ledger.pendingFraction)
            if steps > 0 {
                ledger.pendingFraction -= Double(steps)
                ledger.add(steps: steps, dayKey: todayKey)
            }
            ledger.recentSamples.removeAll { date.timeIntervalSince($0.date) > Self.recentWindowSeconds }
            if steps > 0 {
                ledger.recentSamples.append(StepSample(date: date, steps: steps))
            }
            var recordsToSave: [StepRecord]?
            if ledger.hasUnsavedChanges, Self.shouldSave(ledger, at: date) {
                ledger.hasUnsavedChanges = false
                ledger.lastSavedDate = date
                recordsToSave = ledger.records
            }
            state.stepLedger = ledger
            return (ledger.statistics(todayKey: todayKey), recordsToSave)
        }
        if let recordsToSave = result.recordsToSave {
            try? applicationSupportRepository.saveStepRecords(recordsToSave)
        }
        appStateClient.send(\.stepStatistics, result.statistics)
    }

    /// Stops counting without losing the records, so that counting can resume where it left off.
    private func pause(at date: Date) {
        appStateClient.withLock { state in
            state.stepLedger.lastSampleDate = date
            state.stepLedger.pendingFraction = 0
            state.stepLedger.recentSamples.removeAll()
        }
        guard appStateClient.withLock(\.stepStatistics.latestValue) != StepStatistics.empty else {
            return
        }
        appStateClient.send(\.stepStatistics, .empty)
    }

    /// Writes the records that have not been persisted yet, e.g. when the app terminates.
    func flush() {
        let records = appStateClient.withLock { state -> [StepRecord]? in
            guard state.stepLedger.hasUnsavedChanges else { return nil }
            return state.stepLedger.records
        }
        guard let records else { return }
        do {
            try applicationSupportRepository.saveStepRecords(records)
        } catch {
            return
        }
        appStateClient.withLock { state in
            state.stepLedger.hasUnsavedChanges = false
        }
    }

    static func steps(speed: Float, frameCount: Int, interval: TimeInterval) -> Double {
        guard interval > 0, frameCount > 1 else { return 0 }
        return max(0, Double(speed)) * cyclesPerSecondAtUnitSpeed * interval / Double(frameCount)
    }

    static func interval(from lastSampleDate: Date?, to date: Date) -> TimeInterval {
        guard let lastSampleDate else { return 0 }
        return min(max(date.timeIntervalSince(lastSampleDate), 0), maximumSampleInterval)
    }

    static func shouldSave(_ ledger: StepLedger, at date: Date) -> Bool {
        guard let lastSavedDate = ledger.lastSavedDate else { return true }
        return date.timeIntervalSince(lastSavedDate) >= saveInterval
    }

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year,
              let month = components.month,
              let day = components.day else {
            return ""
        }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    static func pruned(_ records: [StepRecord]) -> [StepRecord] {
        let sorted = records.sorted { $0.dayKey < $1.dayKey }
        guard sorted.count > retentionDays else { return sorted }
        return Array(sorted.suffix(retentionDays))
    }
}
