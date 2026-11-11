/*
 RunnerRotationService.swift
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

struct RunnerRotationService {
    private let appStateClient: AppStateClient
    private let clockClient: ClockClient
    private let randomClient: RandomClient
    private let userDefaultsRepository: UserDefaultsRepository
    private let logService: LogService
    private let runnerService: RunnerService

    init(_ appDependencies: AppDependencies) {
        appStateClient = appDependencies.appStateClient
        clockClient = appDependencies.clockClient
        randomClient = appDependencies.randomClient
        userDefaultsRepository = .init(appDependencies.userDefaultsClient)
        logService = .init(appDependencies)
        runnerService = .init(appDependencies)
    }

    func startRotation() {
        stopRotation()
        let configuration = userDefaultsRepository.runnerRotationConfiguration
        guard configuration.isEnabled, configuration.runnerIDs.count > 1 else {
            return
        }
        let task = Task {
            while !Task.isCancelled {
                do {
                    try await clockClient.sleep(configuration.interval.duration)
                } catch {
                    return
                }
                rotateRunner(with: configuration)
            }
        }
        appStateClient.withLock { $0.runnerRotationTask = task }
    }

    func stopRotation() {
        appStateClient.withLock {
            $0.runnerRotationTask?.cancel()
            $0.runnerRotationTask = nil
        }
    }

    func rotateRunner(with configuration: RunnerRotationConfiguration) {
        let runners = configuration.runnerIDs.compactMap(runnerService.runner(of:))
        let currentRunnerID = appStateClient.withLock(\.runnerBundles.latestValue)?.runner.id
        guard let runner = nextRunner(in: runners, after: currentRunnerID, order: configuration.order) else {
            return
        }
        do {
            try runnerService.update(runner: runner)
        } catch {
            logService.error(.switchingRunnerFailed(error))
        }
    }

    func nextRunner(in runners: [Runner], after currentRunnerID: Runner.ID?, order: RunnerRotationOrder) -> Runner? {
        switch order {
        case .sequential:
            guard let index = runners.firstIndex(where: { $0.id == currentRunnerID }) else {
                return runners.first
            }
            return runners[(index + 1) % runners.count]
        case .random:
            let candidates = runners.filter { $0.id != currentRunnerID }
            guard !candidates.isEmpty else {
                return nil
            }
            return candidates[randomClient.int(candidates.indices)]
        }
    }
}
