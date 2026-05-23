/*
 GeneralSettings.swift
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

@MainActor @Observable
public final class GeneralSettings: Composable {
    private let launchAtLoginRepository: LaunchAtLoginRepository
    private let userDefaultsRepository: UserDefaultsRepository
    private let logService: LogService
    private let runnerService: RunnerService
    private let systemInfoService: SystemInfoService

    public var speedDecreasesUnderLoad: Bool
    public var isFlippedHorizontally: Bool
    public var launchesAtLogin: Bool
    public let action: (Action) async -> Void

    public init(
        _ appDependencies: AppDependencies,
        speedDecreasesUnderLoad: Bool? = nil,
        isFlippedHorizontally: Bool? = nil,
        launchesAtLogin: Bool? = nil,
        action: @escaping (Action) async -> Void =  { _ in }
    ) {
        self.launchAtLoginRepository = .init(appDependencies.smAppServiceClient)
        self.userDefaultsRepository = .init(appDependencies.userDefaultsClient)
        self.logService = .init(appDependencies)
        self.runnerService = .init(appDependencies)
        self.systemInfoService = .init(appDependencies)
        self.speedDecreasesUnderLoad = speedDecreasesUnderLoad ?? userDefaultsRepository.speedDecreasesUnderLoad
        self.isFlippedHorizontally = isFlippedHorizontally ?? userDefaultsRepository.isFlippedHorizontally
        self.launchesAtLogin =  launchesAtLogin ?? launchAtLoginRepository.isEnabled
        self.action = action
    }

    public func reduce(_ action: Action) async {
        switch action {
        case let .task(screenName):
            logService.notice(.screenView(name: screenName))

        case let .slowDownUnderLoadToggleSwitched(isOn):
            speedDecreasesUnderLoad = isOn
            userDefaultsRepository.speedDecreasesUnderLoad = isOn
            let cpuInfo = systemInfoService.currentSystemInfoBundle.cpuInfo
            runnerService.updateRunnerSpeed(from: cpuInfo)

        case let .flipHorizontallyToggleSwitched(isOn):
            isFlippedHorizontally = isOn
            userDefaultsRepository.isFlippedHorizontally = isOn
            runnerService.resendCurrentRunnerBundle()

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
        case slowDownUnderLoadToggleSwitched(Bool)
        case flipHorizontallyToggleSwitched(Bool)
        case launchAtLoginToggleSwitched(Bool)
    }
}
