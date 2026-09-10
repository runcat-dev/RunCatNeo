/*
 RunnerSettings.swift
 Model

 Created by Takuto Nakamura on 2026/06/08.
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
public final class RunnerSettings: Composable {
    private let userDefaultsRepository: UserDefaultsRepository
    private let logService: LogService
    private let runnerService: RunnerService
    private let systemMetricsService: SystemMetricsService

    public var speedDecreasesUnderLoad: Bool
    public var isFlippedHorizontally: Bool
    public let customRunnerSettings: CustomRunnerSettings
    public let action: (Action) async -> Void

    public init(
        _ appDependencies: AppDependencies,
        speedDecreasesUnderLoad: Bool? = nil,
        isFlippedHorizontally: Bool? = nil,
        customRunnerSettings: CustomRunnerSettings? = nil,
        action: @escaping (Action) async -> Void = { _ in }
    ) {
        self.userDefaultsRepository = .init(appDependencies.userDefaultsClient)
        self.logService = .init(appDependencies)
        self.runnerService = .init(appDependencies)
        self.systemMetricsService = .init(appDependencies)
        self.speedDecreasesUnderLoad = speedDecreasesUnderLoad ?? userDefaultsRepository.speedDecreasesUnderLoad
        self.isFlippedHorizontally = isFlippedHorizontally ?? userDefaultsRepository.isFlippedHorizontally
        weak var weakSelf: RunnerSettings? = nil
        self.customRunnerSettings = customRunnerSettings ??
            .init(appDependencies, action: { await weakSelf?.send(.customRunnerSettings($0)) })
        self.action = action
        weakSelf = self
    }

    public func reduce(_ action: Action) async {
        switch action {
        case let .viewAppeared(screenName):
            logService.notice(.screenView(name: screenName))

        case let .slowDownUnderLoadToggleSwitched(isOn):
            speedDecreasesUnderLoad = isOn
            userDefaultsRepository.speedDecreasesUnderLoad = isOn
            let cpuInfo = systemMetricsService.currentSystemInfoBundle.cpuInfo
            runnerService.updateRunnerSpeed(from: cpuInfo)

        case let .flipHorizontallyToggleSwitched(isOn):
            isFlippedHorizontally = isOn
            userDefaultsRepository.isFlippedHorizontally = isOn
            runnerService.resendCurrentRunnerBundle()

        case .customRunnerSettings:
            return
        }
    }

    public enum Action: Sendable {
        case viewAppeared(String)
        case slowDownUnderLoadToggleSwitched(Bool)
        case flipHorizontallyToggleSwitched(Bool)
        case customRunnerSettings(CustomRunnerSettings.Action)
    }
}
