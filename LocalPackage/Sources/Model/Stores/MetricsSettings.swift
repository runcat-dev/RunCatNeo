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
    private let userDefaultsRepository: UserDefaultsRepository
    private let logService: LogService
    private let systemInfoService: SystemInfoService

    public var activationBundle: ActivationBundle
    public let action: (Action) async -> Void

    public init(
        _ appDependencies: AppDependencies,
        activationBundle: ActivationBundle? = nil,
        action: @escaping (Action) async -> Void =  { _ in }
    ) {
        self.userDefaultsRepository = .init(appDependencies.userDefaultsClient)
        self.logService = .init(appDependencies)
        self.systemInfoService = .init(appDependencies)
        self.activationBundle = activationBundle ?? userDefaultsRepository.activationBundle
        self.action = action
    }

    public func reduce(_ action: Action) async {
        switch action {
        case let .task(screenName):
            logService.notice(.screenView(name: screenName))

        case let .isActiveToggleSwitched(type, isOn):
            switch type {
            case .memory:
                activationBundle.isActiveMemory = isOn
            case .storage:
                activationBundle.isActiveStorage = isOn
            case .battery:
                activationBundle.isActiveBattery = isOn
            case .network:
                activationBundle.isActiveNetwork = isOn
            default:
                break
            }
            userDefaultsRepository.activationBundle = activationBundle
            systemInfoService.toggleSystemInfoActivation(type: type, isOn: isOn)
        }
    }

    public enum Action: Sendable {
        case task(String)
        case isActiveToggleSwitched(SystemInfoType, Bool)
    }
}
