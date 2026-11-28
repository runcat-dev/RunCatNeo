/*
 StepLedger.swift
 DataSource

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

import Foundation

public struct StepSample: Sendable {
    public let date: Date
    public let steps: Int

    public init(date: Date, steps: Int) {
        self.date = date
        self.steps = steps
    }
}

/// The live bookkeeping state of the step counter, kept in `AppState` so that the
/// service can update it safely from whichever thread the system metrics arrive on.
public struct StepLedger: Sendable {
    /// Daily records sorted in ascending order of `dayKey`.
    public var records: [StepRecord]

    /// When the last runner speed sample was taken.
    public var lastSampleDate: Date?

    /// When the records were written to disk last time.
    public var lastSavedDate: Date?

    /// Steps that have not been rounded up to a whole step yet.
    public var pendingFraction: Double

    /// Whether the records on disk are older than the records in memory.
    public var hasUnsavedChanges: Bool

    /// The steps recorded during the most recent minute.
    public var recentSamples: [StepSample]

    public init(
        records: [StepRecord] = [],
        lastSampleDate: Date? = nil,
        lastSavedDate: Date? = nil,
        pendingFraction: Double = 0,
        hasUnsavedChanges: Bool = false,
        recentSamples: [StepSample] = []
    ) {
        self.records = records
        self.lastSampleDate = lastSampleDate
        self.lastSavedDate = lastSavedDate
        self.pendingFraction = pendingFraction
        self.hasUnsavedChanges = hasUnsavedChanges
        self.recentSamples = recentSamples
    }

    public var stepsInLastMinute: Int {
        recentSamples.reduce(0) { $0 + $1.steps }
    }

    public mutating func add(steps: Int, dayKey: String) {
        guard !dayKey.isEmpty, steps > 0 else { return }
        if let index = records.firstIndex(where: { $0.dayKey == dayKey }) {
            records[index].steps += steps
        } else {
            records.append(StepRecord(dayKey: dayKey, steps: steps))
            records.sort { $0.dayKey < $1.dayKey }
        }
        hasUnsavedChanges = true
    }

    public func statistics(todayKey: String) -> StepStatistics {
        StepStatistics(records: records, todayKey: todayKey, stepsInLastMinute: stepsInLastMinute)
    }
}
