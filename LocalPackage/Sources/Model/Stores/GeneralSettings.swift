/*
 GeneralSettings.swift
 Model

 Created by Takuto Nakamura on 2026/05/23.
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
import Observation

@MainActor @Observable
public final class GeneralSettings: Composable {
    private let launchAtLoginRepository: LaunchAtLoginRepository
    private let userDefaultsRepository: UserDefaultsRepository
    private let logService: LogService
    private let systemMetricsService: SystemMetricsService

    public var updateInterval: UpdateInterval
    public var launchesAtLogin: Bool
    public let action: (Action) async -> Void

    public init(
        _ appDependencies: AppDependencies,
        updateInterval: UpdateInterval? = nil,
        launchesAtLogin: Bool? = nil,
        action: @escaping (Action) async -> Void = { _ in }
    ) {
        self.launchAtLoginRepository = .init(appDependencies.smAppServiceClient)
        self.userDefaultsRepository = .init(appDependencies.userDefaultsClient)
        self.logService = .init(appDependencies)
        self.systemMetricsService = .init(appDependencies)
        self.updateInterval = updateInterval ?? userDefaultsRepository.updateInterval
        self.launchesAtLogin = launchesAtLogin ?? launchAtLoginRepository.isEnabled
        self.action = action
    }

    public func reduce(_ action: Action) async {
        switch action {
        case let .task(screenName):
            logService.notice(.screenView(name: screenName))

        case let .updateIntervalChanged(interval):
            updateInterval = interval
            userDefaultsRepository.updateInterval = interval
            systemMetricsService.stopMonitoring()
            systemMetricsService.startMonitoring()

        case let .launchAtLoginToggleSwitched(isOn):
            switch launchAtLoginRepository.switchStatus(isOn) {
            case .success:
                launchesAtLogin = isOn
            case let .failure(.switchFailed(value)):
                launchesAtLogin = value
            }
        }
    }

    public enum Action: Sendable {
        case task(String)
        case updateIntervalChanged(UpdateInterval)
        case launchAtLoginToggleSwitched(Bool)
    }
}
