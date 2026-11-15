/*
 BatteryHealthService.swift
 Model

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

actor BatteryHealthService {
    private let dateClient: DateClient
    private let systemPowerReportRepository: SystemPowerReportRepository

    private var cachedValue: Double?
    private var expiresAt: Date?
    private var refreshTask: Task<Double?, Never>?

    init(_ appDependencies: AppDependencies) {
        self.dateClient = appDependencies.dateClient
        self.systemPowerReportRepository = .init(appDependencies.processClient)
    }

    func maximumCapacityPercent() async -> Double? {
        if let expiresAt, dateClient.now() < expiresAt { return cachedValue }
        if let refreshTask { return await refreshTask.value }
        let task = Task.detached(priority: .utility) { [systemPowerReportRepository] in
            systemPowerReportRepository.read().flatMap(BatteryHealthReport.maximumCapacityPercent)
        }
        refreshTask = task
        let value = await task.value
        cachedValue = value
        expiresAt = dateClient.now().addingTimeInterval(value == nil ? 30 : 300)
        refreshTask = nil
        return value
    }
}
