/*
 MetricsBarSettings.swift
 Model

 Created by Takuto Nakamura on 2026/05/24.
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
import Observation
import SystemInfoKit

@MainActor @Observable
public final class MetricsBarSettings: Composable {
    private let appStateClient: AppStateClient
    private let userDefaultsRepository: UserDefaultsRepository
    private let logService: LogService
    private let systemMetricsService: SystemMetricsService

    @ObservationIgnored private var task: Task<Void, Never>?

    public var metricsBarConfiguration: MetricsBarConfiguration
    public var customMetricsSources: [CustomMetricsSource]
    public let action: (Action) async -> Void

    public init(
        _ appDependencies: AppDependencies,
        metricsBarConfiguration: MetricsBarConfiguration? = nil,
        customMetricsSources: [CustomMetricsSource]? = nil,
        action: @escaping (Action) async -> Void =  { _ in }
    ) {
        self.appStateClient = appDependencies.appStateClient
        self.userDefaultsRepository = .init(appDependencies.userDefaultsClient)
        self.logService = .init(appDependencies)
        self.systemMetricsService = .init(appDependencies)
        self.metricsBarConfiguration = metricsBarConfiguration ?? userDefaultsRepository.metricsBarConfiguration
        self.customMetricsSources = customMetricsSources ?? userDefaultsRepository.customMetricsConfiguration.sources
        self.action = action
    }

    public func reduce(_ action: Action) async {
        switch action {
        case let .viewAppeared(screenName):
            logService.notice(.screenView(name: screenName))
            metricsBarConfiguration = userDefaultsRepository.metricsBarConfiguration
            customMetricsSources = userDefaultsRepository.customMetricsConfiguration.sources
            task?.cancel()
            task = Task.immediate { [weak self, appStateClient] in
                let stream = appStateClient.withLock(\.customMetricsConfigurationChanges.stream)
                for await _ in stream {
                    self?.updateCustomMetricsConfiguration()
                }
            }

        case .viewDisappeared:
            task?.cancel()
            task = nil


        case let .cpuStylePickerSelected(style):
            if let style {
                metricsBarConfiguration.cpuStyle = style
            }
            switchSystemMetrics(type: .cpu, isOn: style != nil)

        case let .memoryStylePickerSelected(style):
            if let style {
                metricsBarConfiguration.memoryStyle = style
            }
            switchSystemMetrics(type: .memory, isOn: style != nil)

        case let .storageStylePickerSelected(style):
            if let style {
                metricsBarConfiguration.storageStyle = style
            }
            switchSystemMetrics(type: .storage, isOn: style != nil)

        case let .showBatteryToggleSwitched(isOn):
            switchSystemMetrics(type: .battery, isOn: isOn)

        case let .showNetworkToggleSwitched(isOn):
            switchSystemMetrics(type: .network, isOn: isOn)

        case let .showCustomMetricsToggleSwitched(id, isOn):
            if isOn {
                metricsBarConfiguration.visibleCustomMetricsSourceIDs.insert(id)
            } else {
                metricsBarConfiguration.visibleCustomMetricsSourceIDs.remove(id)
            }
            saveMetricsBarConfiguration()
        }
    }

    private func switchSystemMetrics(type: SystemInfoType, isOn: Bool) {
        func overwrite(isOn: Bool, monitors: inout Bool) -> Bool {
            if isOn, !monitors {
                monitors = true
                return true
            } else {
                return false
            }
        }
        var configuration = userDefaultsRepository.systemMetricsConfiguration
        var needsToggleActivation = false
        switch type {
        case .cpu:
            metricsBarConfiguration.showsCPU = isOn
        case .memory:
            metricsBarConfiguration.showsMemory = isOn
            needsToggleActivation = overwrite(isOn: isOn, monitors: &configuration.monitorsMemory)
        case .storage:
            metricsBarConfiguration.showsStorage = isOn
            needsToggleActivation = overwrite(isOn: isOn, monitors: &configuration.monitorsStorage)
        case .battery:
            metricsBarConfiguration.showsBattery = isOn
            needsToggleActivation = overwrite(isOn: isOn, monitors: &configuration.monitorsBattery)
        case .network:
            metricsBarConfiguration.showsNetwork = isOn
            needsToggleActivation = overwrite(isOn: isOn, monitors: &configuration.monitorsNetwork)
        }
        userDefaultsRepository.metricsBarConfiguration = metricsBarConfiguration
        userDefaultsRepository.systemMetricsConfiguration = configuration
        systemMetricsService.emitConfigurationChange()
        if needsToggleActivation {
            systemMetricsService.toggleSystemMetricsActivation(type: type, isOn: isOn)
        }
    }

    private func saveMetricsBarConfiguration() {
        userDefaultsRepository.metricsBarConfiguration = metricsBarConfiguration
        systemMetricsService.emitConfigurationChange()
    }

    private func updateCustomMetricsConfiguration() {
        customMetricsSources = userDefaultsRepository.customMetricsConfiguration.sources
        metricsBarConfiguration = userDefaultsRepository.metricsBarConfiguration
    }

    public enum Action: Sendable {
        case viewAppeared(String)
        case viewDisappeared
        case cpuStylePickerSelected(MetricsBarUsageStyle?)
        case memoryStylePickerSelected(MetricsBarUsageStyle?)
        case storageStylePickerSelected(MetricsBarStorageStyle?)
        case showBatteryToggleSwitched(Bool)
        case showNetworkToggleSwitched(Bool)
        case showCustomMetricsToggleSwitched(UUID, Bool)
    }
}
