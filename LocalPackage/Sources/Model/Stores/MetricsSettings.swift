/*
 MetricsSettings.swift
 Model

 Created by Takuto Nakamura on 2026/05/23.
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
public final class MetricsSettings: Composable {
    private let appStateClient: AppStateClient
    private let userDefaultsRepository: UserDefaultsRepository
    private let logService: LogService
    private let metricsService: MetricsService

    @ObservationIgnored private var task: Task<Void, Never>?

    public var showsMetricsBar: Bool
    public var metricsConfiguration: MetricsConfiguration
    public let action: (Action) async -> Void

    public init(
        _ appDependencies: AppDependencies,
        showsMetricsBar: Bool? = nil,
        metricsConfiguration: MetricsConfiguration? = nil,
        action: @escaping (Action) async -> Void =  { _ in }
    ) {
        self.appStateClient = appDependencies.appStateClient
        self.userDefaultsRepository = .init(appDependencies.userDefaultsClient)
        self.logService = .init(appDependencies)
        self.metricsService = .init(appDependencies)
        self.showsMetricsBar = showsMetricsBar ?? userDefaultsRepository.showsMetricsBar
        self.metricsConfiguration = metricsConfiguration ?? userDefaultsRepository.metricsConfiguration
        self.action = action
    }

    public func reduce(_ action: Action) async {
        switch action {
        case let .task(screenName):
            logService.notice(.screenView(name: screenName))
            task?.cancel()
            task = Task { [weak self, appStateClient] in
                let stream = appStateClient.withLock(\.metricsConfigurationChanges.stream)
                for await _ in stream {
                    self?.updateMetricsConfiguration()
                }
            }

        case let .showsMetricsBarToggleSwitched(isOn):
            showsMetricsBar = isOn
            userDefaultsRepository.showsMetricsBar = isOn

        case let .monitorsSystemInfoToggleSwitched(type, isOn):
            func overwrite(isOn: Bool, shows: inout Bool) {
                shows = shows && isOn
            }
            var metricsBarConfiguration = userDefaultsRepository.metricsBarConfiguration
            switch type {
            case .cpu:
                return
            case .memory:
                metricsConfiguration.monitorsMemory = isOn
                overwrite(isOn: isOn, shows: &metricsBarConfiguration.showsMemory)
            case .storage:
                metricsConfiguration.monitorsStorage = isOn
                overwrite(isOn: isOn, shows: &metricsBarConfiguration.showsStorage)
            case .battery:
                metricsConfiguration.monitorsBattery = isOn
                overwrite(isOn: isOn, shows: &metricsBarConfiguration.showsBattery)
            case .network:
                metricsConfiguration.monitorsNetwork = isOn
                overwrite(isOn: isOn, shows: &metricsBarConfiguration.showsNetwork)
            }
            userDefaultsRepository.metricsConfiguration = metricsConfiguration
            userDefaultsRepository.metricsBarConfiguration = metricsBarConfiguration
            metricsService.toggleSystemInfoActivation(type: type, isOn: isOn)
            metricsService.emitMetricsConfigurationChange()
        }
    }

    private func updateMetricsConfiguration() {
        metricsConfiguration = userDefaultsRepository.metricsConfiguration
    }

    public enum Action: Sendable {
        case task(String)
        case showsMetricsBarToggleSwitched(Bool)
        case monitorsSystemInfoToggleSwitched(SystemInfoType, Bool)
    }
}
