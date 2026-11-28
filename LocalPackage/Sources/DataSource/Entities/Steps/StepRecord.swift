/*
 StepRecord.swift
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

public struct StepRecord: Codable, Hashable, Sendable, Identifiable {
    public var id: String { dayKey }

    /// The day the steps were taken on, formatted as `yyyy-MM-dd` in the user's calendar.
    public let dayKey: String

    /// The number of steps the runner took on the day.
    public var steps: Int

    public init(dayKey: String, steps: Int) {
        self.dayKey = dayKey
        self.steps = steps
    }
}

public struct StepStatistics: Sendable, Equatable {
    public static let empty = StepStatistics(records: [], todayKey: "")

    /// Daily records sorted in ascending order of `dayKey`.
    public let records: [StepRecord]

    /// The day key of the day the statistics are calculated for.
    public let todayKey: String

    /// The steps the runner took during the most recent minute.
    public let stepsInLastMinute: Int

    public init(records: [StepRecord], todayKey: String, stepsInLastMinute: Int = 0) {
        self.records = records.sorted { $0.dayKey < $1.dayKey }
        self.todayKey = todayKey
        self.stepsInLastMinute = stepsInLastMinute
    }

    public var todaySteps: Int {
        records.first { $0.dayKey == todayKey }?.steps ?? 0
    }

    public var totalSteps: Int {
        records.reduce(0) { $0 + $1.steps }
    }

    /// The most recent `limit` days that have a record, oldest first.
    public func recentRecords(limit: Int) -> [StepRecord] {
        Array(records.suffix(max(0, limit)))
    }
}
