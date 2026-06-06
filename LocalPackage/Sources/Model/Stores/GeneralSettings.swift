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
    private let appStateClient: AppStateClient
    private let launchAtLoginRepository: LaunchAtLoginRepository
    private let userDefaultsRepository: UserDefaultsRepository
    private let logService: LogService
    private let runnerService: RunnerService
    private let systemMetricsService: SystemMetricsService

    @ObservationIgnored private var task: Task<Void, Never>?

    public var currentRunner: Runner?
    public var runnerBundleList: [RunnerBundle]
    public var speedDecreasesUnderLoad: Bool
    public var isFlippedHorizontally: Bool
    public var showsMetricsBar: Bool
    public var launchesAtLogin: Bool
    public let action: (Action) async -> Void

    public init(
        _ appDependencies: AppDependencies,
        currentRunner: Runner? = nil,
        runnerBundleList: [RunnerBundle] = [],
        speedDecreasesUnderLoad: Bool? = nil,
        isFlippedHorizontally: Bool? = nil,
        showsMetricsBar: Bool? = nil,
        launchesAtLogin: Bool? = nil,
        action: @escaping (Action) async -> Void =  { _ in }
    ) {
        self.appStateClient = appDependencies.appStateClient
        self.launchAtLoginRepository = .init(appDependencies.smAppServiceClient)
        self.userDefaultsRepository = .init(appDependencies.userDefaultsClient)
        self.logService = .init(appDependencies)
        self.runnerService = .init(appDependencies)
        self.systemMetricsService = .init(appDependencies)
        self.currentRunner = currentRunner
        self.runnerBundleList = runnerBundleList
        self.speedDecreasesUnderLoad = speedDecreasesUnderLoad ?? userDefaultsRepository.speedDecreasesUnderLoad
        self.isFlippedHorizontally = isFlippedHorizontally ?? userDefaultsRepository.isFlippedHorizontally
        self.showsMetricsBar = showsMetricsBar ?? userDefaultsRepository.showsMetricsBar
        self.launchesAtLogin =  launchesAtLogin ?? launchAtLoginRepository.isEnabled
        self.action = action
    }

    public func reduce(_ action: Action) async {
        switch action {
        case let .task(screenName):
            logService.notice(.screenView(name: screenName))
            if let runnerBundle = appStateClient.withLock(\.runnerBundles.latestValue) {
                currentRunner = runnerBundle.runner
            }
            task?.cancel()
            task = Task { [weak self, appStateClient] in
                await withTaskGroup { group in
                    group.addTask {
                        let stream = appStateClient.withLock(\.runnerBundles.stream)
                        for await value in stream {
                            await self?.updateCurrentRunner(from: value)
                        }
                    }
                    group.addTask {
                        let stream = appStateClient.withLock(\.runnerBundleLists.stream)
                        for await value in stream {
                            await self?.update(runnerBundleList: value)
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
                logService.critical(.savingCustomRunnerFailed(error))
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

        case let .showMetricsBarToggleSwitched(isOn):
            showsMetricsBar = isOn
            userDefaultsRepository.showsMetricsBar = isOn

        case let .launchAtLoginToggleSwitched(isOn):
            switch launchAtLoginRepository.switchStatus(isOn) {
            case .success:
                launchesAtLogin = isOn
            case let .failure(.switchFailed(value)):
                launchesAtLogin = value
            }
        }
    }

    private func updateCurrentRunner(from runnerBundle: RunnerBundle) {
        currentRunner = runnerBundle.runner
    }

    private func update(runnerBundleList: [RunnerBundle]) {
        self.runnerBundleList = runnerBundleList
    }

    public enum Action: Sendable {
        case task(String)
        case onDisappear
        case selectRunner(Runner?)
        case slowDownUnderLoadToggleSwitched(Bool)
        case flipHorizontallyToggleSwitched(Bool)
        case showMetricsBarToggleSwitched(Bool)
        case launchAtLoginToggleSwitched(Bool)
    }
}
