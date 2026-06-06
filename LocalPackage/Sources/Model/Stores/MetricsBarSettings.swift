/*
 MetricsBarSettings.swift
 Model

 Created by Takuto Nakamura on 2026/05/24.
 Copyright 2026 Koyme22 (Takuto Nakamura)

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
import Observation
import SystemInfoKit

@MainActor @Observable
public final class MetricsBarSettings: Composable {
    private let userDefaultsRepository: UserDefaultsRepository
    private let logService: LogService
    private let systemMetricsService: SystemMetricsService

    public var metricsBarConfiguration: MetricsBarConfiguration
    public let action: (Action) async -> Void

    public init(
        _ appDependencies: AppDependencies,
        metricsBarConfiguration: MetricsBarConfiguration? = nil,
        action: @escaping (Action) async -> Void =  { _ in }
    ) {
        self.userDefaultsRepository = .init(appDependencies.userDefaultsClient)
        self.logService = .init(appDependencies)
        self.systemMetricsService = .init(appDependencies)
        self.metricsBarConfiguration = metricsBarConfiguration ?? userDefaultsRepository.metricsBarConfiguration
        self.action = action
    }

    public func reduce(_ action: Action) async {
        switch action {
        case let .task(screenName):
            logService.notice(.screenView(name: screenName))
            metricsBarConfiguration = userDefaultsRepository.metricsBarConfiguration

        case let .showsSystemInfoToggleSwitched(type, isOn):
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
                systemMetricsService.toggleSystemInfoActivation(type: type, isOn: isOn)
            }
        }
    }

    public enum Action: Sendable {
        case task(String)
        case showsSystemInfoToggleSwitched(SystemInfoType, Bool)
    }
}
