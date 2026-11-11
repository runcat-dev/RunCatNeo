/*
 RunnerRotationSettings.swift
 Model

 Created by Jimmy on 2026/11/12.
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
public final class RunnerRotationSettings: Composable {
    private let appStateClient: AppStateClient
    private let userDefaultsRepository: UserDefaultsRepository
    private let runnerRotationService: RunnerRotationService

    @ObservationIgnored private var task: Task<Void, Never>?

    public var isEnabled: Bool
    public var order: RunnerRotationOrder
    public var interval: RunnerRotationInterval
    public var runnerIDs: [Runner.ID]
    public var runnerBundleList: [RunnerBundle]
    public let action: (Action) async -> Void

    public var needsMoreRunners: Bool {
        isEnabled && runnerIDs.count < 2
    }

    public init(
        _ appDependencies: AppDependencies,
        configuration: RunnerRotationConfiguration? = nil,
        runnerBundleList: [RunnerBundle] = [],
        action: @escaping (Action) async -> Void = { _ in }
    ) {
        self.appStateClient = appDependencies.appStateClient
        self.userDefaultsRepository = .init(appDependencies.userDefaultsClient)
        self.runnerRotationService = .init(appDependencies)
        let configuration = configuration ?? userDefaultsRepository.runnerRotationConfiguration
        self.isEnabled = configuration.isEnabled
        self.order = configuration.order
        self.interval = configuration.interval
        self.runnerIDs = configuration.runnerIDs
        self.runnerBundleList = runnerBundleList
        self.action = action
    }

    public func reduce(_ action: Action) async {
        switch action {
        case .viewAppeared:
            runnerBundleList = appStateClient.withLock(\.runnerBundleLists.latestValue) ?? []
            task?.cancel()
            task = Task.immediate { [weak self, appStateClient] in
                let stream = appStateClient.withLock(\.runnerBundleLists.stream)
                for await value in stream {
                    self?.runnerBundleList = value
                }
            }

        case .viewDisappeared:
            task?.cancel()
            task = nil

        case let .rotationToggleSwitched(isOn):
            isEnabled = isOn
            saveConfiguration()

        case let .orderPickerSelected(order):
            self.order = order
            saveConfiguration()

        case let .intervalPickerSelected(interval):
            self.interval = interval
            saveConfiguration()

        case let .runnerToggleSwitched(runner, isOn):
            var selectedIDs = Set(runnerIDs)
            if isOn {
                selectedIDs.insert(runner.id)
            } else {
                selectedIDs.remove(runner.id)
            }
            runnerIDs = runnerBundleList.map(\.runner.id).filter(selectedIDs.contains)
            saveConfiguration()
        }
    }

    private func saveConfiguration() {
        userDefaultsRepository.runnerRotationConfiguration = .init(
            isEnabled: isEnabled,
            order: order,
            interval: interval,
            runnerIDs: runnerIDs
        )
        runnerRotationService.startRotation()
    }

    public enum Action: Sendable {
        case viewAppeared
        case viewDisappeared
        case rotationToggleSwitched(Bool)
        case orderPickerSelected(RunnerRotationOrder)
        case intervalPickerSelected(RunnerRotationInterval)
        case runnerToggleSwitched(Runner, Bool)
    }
}
