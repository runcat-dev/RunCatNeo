/*
 RunnerService.swift
 Model

 Created by Takuto Nakamura on 2026/05/07.
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
import SystemInfoKit

struct RunnerService {
    private let appStateClient: AppStateClient
    private let applicationSupportRepository: ApplicationSupportRepository
    private let userDefaultsRepository: UserDefaultsRepository

    init(_ appDependencies: AppDependencies) {
        appStateClient = appDependencies.appStateClient
        applicationSupportRepository = .init(appDependencies.dataClient, appDependencies.fileManagerClient)
        userDefaultsRepository = .init(appDependencies.userDefaultsClient)
    }

    private func prepareRunnerBundle(of runner: Runner) -> RunnerBundle? {
        let names = runner.resourceNames()
        let frames = names.compactMap { name -> Frame? in
            if runner.isCustom {
                if let data = applicationSupportRepository.loadData(directory: runner.id, fileName: name, fileType: .png) {
                    Frame.custom(data)
                } else {
                    nil
                }
            } else {
                Frame.preset(name)
            }
        }
        guard names.count == frames.count else {
            return nil
        }
        return RunnerBundle(runner: runner, frames: frames)
    }

    func update(runner: Runner) {
        guard let runnerBundle = prepareRunnerBundle(of: runner) else {
            fatalError("Failed to prepare RunnerBundle.")
        }
        userDefaultsRepository.runnerID = runner.id
        appStateClient.withLock {
            $0.runnerBundle = runnerBundle
            $0.runnerBundles.send(runnerBundle)
        }
    }

    func setup() {
        let runnerID = userDefaultsRepository.runnerID
        let runner = if let kind = RunnerKind(rawValue: runnerID) {
            Runner(kind: kind)
        } else if let runners = applicationSupportRepository.loadCustomRunners(),
                  let runner = runners.first(where: { $0.id == runnerID }) {
            runner
        } else {
            Runner.default
        }
        update(runner: runner)
    }

    func updateRunnerSpeed(from cpuInfo: CPUInfo?) {
        let cpuValue = max(1.0, min(20.0, Float(cpuInfo?.percentage.value ?? .zero) / 5.0))
        let speed: Float = if userDefaultsRepository.speedDecreasesUnderLoad {
            0.5 * (21.0 - cpuValue)
        } else {
            cpuValue
        }
        appStateClient.withLock {
            $0.runnerSpeeds.send(speed)
        }
    }

    func resendCurrentRunnerBundle() {
        appStateClient.withLock {
            if let runnerBundle = $0.runnerBundle {
                $0.runnerBundles.send(runnerBundle)
            }
        }
    }
}
