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
import Foundation
import SystemInfoKit

struct RunnerService {
    private let appStateClient: AppStateClient
    private let dataClient: DataClient
    private let applicationSupportRepository: ApplicationSupportRepository
    private let userDefaultsRepository: UserDefaultsRepository

    init(_ appDependencies: AppDependencies) {
        appStateClient = appDependencies.appStateClient
        dataClient = appDependencies.dataClient
        applicationSupportRepository = .init(appDependencies.dataClient, appDependencies.fileManagerClient)
        userDefaultsRepository = .init(appDependencies.userDefaultsClient)
    }

    private func prepareFrame(of runner: Runner, with name: String) throws -> Frame {
        if runner.isCustom {
            if let data = applicationSupportRepository.loadData(directory: runner.id, fileName: name, fileType: .png) {
                Frame.custom(data)
            } else {
                throw RCNError.customRunner(.loadingFailed)
            }
        } else {
            Frame.preset(name)
        }
    }

    func update(runner: Runner) throws {
        let frames = try runner.resourceNames().map {
            try prepareFrame(of: runner, with: $0)
        }
        let runnerBundle = RunnerBundle(runner: runner, frames: frames)
        userDefaultsRepository.runnerID = runner.id
        appStateClient.withLock {
            $0.runnerBundles.send(runnerBundle)
        }
    }

    func loadRunnerBundleList() {
        var runners = RunnerKind.allCases.map(Runner.init(kind:))
        runners.append(contentsOf: applicationSupportRepository.loadCustomRunners())
        let runnerBundles = runners.map { runner in
            guard let name = runner.resourceNames().first,
                  let frame = try? prepareFrame(of: runner, with: name) else {
                return RunnerBundle(runner: runner, frame: .broken)
            }
            return RunnerBundle(runner: runner, frame: frame)
        }
        appStateClient.withLock {
            $0.runnerBundleLists.send(runnerBundles)
        }
    }

    func setup() throws {
        let runnerID = userDefaultsRepository.runnerID
        let runner = if let kind = RunnerKind(rawValue: runnerID) {
            Runner(kind: kind)
        } else if let runner = applicationSupportRepository.loadCustomRunner(of: runnerID) {
            runner
        } else {
            Runner.default
        }
        do {
            try update(runner: runner)
        } catch {
            try update(runner: .default)
        }
        loadRunnerBundleList()
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
            if let runnerBundle = $0.runnerBundles.latestValue {
                $0.runnerBundles.send(runnerBundle)
            }
        }
    }

    func validate(customRunnerName name: String) -> Bool {
        let runners = applicationSupportRepository.loadCustomRunners()
        return !runners.contains { runner in
            if case let .custom(existingName) = runner.source {
                existingName == name
            } else {
                false
            }
        }
    }

    func convertToCustomFrame(from frameImage: FrameImage) throws -> Frame {
        let data = try dataClient.convert(frameImage.cgImage, .png)
        return Frame.custom(data)
    }

    func save(customRunner runner: Runner, with frameImages: [FrameImage]) throws {
        let imageDataList: [Data] = try frameImages.map {
            try dataClient.convert($0.cgImage, .png)
        }
        try imageDataList.enumerated().forEach { index, imageData in
            try applicationSupportRepository.saveData(
                directory: runner.id,
                fileName: "frame-\(index)",
                fileType: .png,
                data: imageData
            )
        }
        let runners = applicationSupportRepository.loadCustomRunners()
        try applicationSupportRepository.saveCustomRunners(runners + [runner])
        loadRunnerBundleList()
    }

    func delete(customRunner runner: Runner) throws {
        var runners = applicationSupportRepository.loadCustomRunners()
        runners.removeAll { $0 == runner }
        try applicationSupportRepository.saveCustomRunners(runners)
        applicationSupportRepository.delete(directory: runner.id)
        loadRunnerBundleList()
    }
}
