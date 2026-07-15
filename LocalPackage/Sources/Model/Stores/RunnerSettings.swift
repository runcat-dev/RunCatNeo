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
    private let appStateClient: AppStateClient
    private let userDefaultsRepository: UserDefaultsRepository
    private let logService: LogService
    private let runnerService: RunnerService
    private let systemMetricsService: SystemMetricsService

    @ObservationIgnored private var task: Task<Void, Never>?

    public var currentRunner: Runner?
    public var runnerBundleList: [RunnerBundle]
    public var speedDecreasesUnderLoad: Bool
    public var isFlippedHorizontally: Bool
    public var showingAlert: Bool
    public var error: RCNError?
    public let customRunnerSettings: CustomRunnerSettings
    public let action: (Action) async -> Void

    public init(
        _ appDependencies: AppDependencies,
        currentRunner: Runner? = nil,
        runnerBundleList: [RunnerBundle] = [],
        speedDecreasesUnderLoad: Bool? = nil,
        isFlippedHorizontally: Bool? = nil,
        showingAlert: Bool = false,
        error: RCNError? = nil,
        customRunnerSettings: CustomRunnerSettings? = nil,
        action: @escaping (Action) async -> Void = { _ in }
    ) {
        self.appStateClient = appDependencies.appStateClient
        self.userDefaultsRepository = .init(appDependencies.userDefaultsClient)
        self.logService = .init(appDependencies)
        self.runnerService = .init(appDependencies)
        self.systemMetricsService = .init(appDependencies)
        self.currentRunner = currentRunner
        self.runnerBundleList = runnerBundleList
        self.speedDecreasesUnderLoad = speedDecreasesUnderLoad ?? userDefaultsRepository.speedDecreasesUnderLoad
        self.isFlippedHorizontally = isFlippedHorizontally ?? userDefaultsRepository.isFlippedHorizontally
        self.showingAlert = showingAlert
        self.error = error
        weak var weakSelf: RunnerSettings? = nil
        self.customRunnerSettings = customRunnerSettings ??
            .init(appDependencies, action: { await weakSelf?.send(.customRunnerSettings($0)) })
        self.action = action
        weakSelf = self
    }

    public func reduce(_ action: Action) async {
        switch action {
        case let .task(screenName):
            logService.notice(.screenView(name: screenName))
            speedDecreasesUnderLoad = userDefaultsRepository.speedDecreasesUnderLoad
            isFlippedHorizontally = userDefaultsRepository.isFlippedHorizontally
            if let runnerBundle = appStateClient.withLock(\.runnerBundles.latestValue) {
                currentRunner = runnerBundle.runner
            }
            task?.cancel()
            task = Task.immediate { [weak self, appStateClient] in
                await withTaskGroup { group in
                    group.addImmediateTask {
                        let stream = appStateClient.withLock(\.runnerBundles.stream)
                        for await value in stream {
                            self?.updateCurrentRunner(from: value)
                        }
                    }
                    group.addImmediateTask {
                        let stream = appStateClient.withLock(\.runnerBundleLists.stream)
                        for await value in stream {
                            self?.update(runnerBundleList: value)
                        }
                    }
                    group.addImmediateTask {
                        let stream = appStateClient.withLock(\.settingsResets.stream)
                        for await _ in stream {
                            self?.resetToDefaults()
                        }
                    }
                }
            }

        case .onDisappear:
            task?.cancel()
            task = nil

        case let .selectRunner(runner):
            guard let runner else { return }
            do {
                try runnerService.update(runner: runner)
                currentRunner = runner
            } catch {
                self.error = .customRunner(.loadingFailed)
                showingAlert = true
            }

        case let .slowDownUnderLoadToggleSwitched(isOn):
            speedDecreasesUnderLoad = isOn
            userDefaultsRepository.speedDecreasesUnderLoad = isOn
            let cpuInfo = systemMetricsService.currentSystemInfoBundle.cpuInfo
            runnerService.updateRunnerSpeed(from: cpuInfo)

        case let .flipHorizontallyToggleSwitched(isOn):
            isFlippedHorizontally = isOn
            userDefaultsRepository.isFlippedHorizontally = isOn
            runnerService.resendCurrentRunnerBundle()

        case let .customRunnerSettings(.onError(error)):
            self.error = error
            showingAlert = true

        case .customRunnerSettings:
            return
        }
    }

    private func updateCurrentRunner(from runnerBundle: RunnerBundle) {
        currentRunner = runnerBundle.runner
    }

    private func update(runnerBundleList: [RunnerBundle]) {
        self.runnerBundleList = runnerBundleList
    }

    private func resetToDefaults() {
        speedDecreasesUnderLoad = userDefaultsRepository.speedDecreasesUnderLoad
        isFlippedHorizontally = userDefaultsRepository.isFlippedHorizontally
        do {
            try runnerService.update(runner: .default)
        } catch {
            logService.critical(.unknown(error))
        }
        let cpuInfo = systemMetricsService.currentSystemInfoBundle.cpuInfo
        runnerService.updateRunnerSpeed(from: cpuInfo)
    }

    public enum Action: Sendable {
        case task(String)
        case onDisappear
        case selectRunner(Runner?)
        case slowDownUnderLoadToggleSwitched(Bool)
        case flipHorizontallyToggleSwitched(Bool)
        case customRunnerSettings(CustomRunnerSettings.Action)
    }
}
