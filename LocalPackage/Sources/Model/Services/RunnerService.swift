/*
 RunnerService.swift
 Model

 Created by Takuto Nakamura on 2026/05/07.
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
import Foundation
import ImageIO
import SystemInfoKit

struct RunnerService {
    private let appStateClient: AppStateClient
    private let dataClient: DataClient
    private let uuidClient: UUIDClient
    private let applicationSupportRepository: ApplicationSupportRepository
    private let userDefaultsRepository: UserDefaultsRepository

    init(_ appDependencies: AppDependencies) {
        appStateClient = appDependencies.appStateClient
        dataClient = appDependencies.dataClient
        uuidClient = appDependencies.uuidClient
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
        appStateClient.send(\.runnerBundles, runnerBundle)
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
        appStateClient.send(\.runnerBundleLists, runnerBundles)
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
        appStateClient.send(\.runnerSpeeds, speed)
    }

    func resendCurrentRunnerBundle() {
        if let runnerBundle = appStateClient.withLock(\.runnerBundles.latestValue) {
            appStateClient.send(\.runnerBundles, runnerBundle)
        }
    }

    func validate(customRunnerName name: String, excluding excludedRunner: Runner? = nil) -> Bool {
        let runners = applicationSupportRepository.loadCustomRunners()
        return !runners.contains { runner in
            if runner != excludedRunner, case let .custom(existingName) = runner.source {
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

    func loadFrameImages(of runner: Runner) throws -> [FrameImage] {
        try runner.resourceNames().map { name in
            guard let data = applicationSupportRepository.loadData(directory: runner.id, fileName: name, fileType: .png),
                  let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                throw RCNError.customRunner(.loadingFailed)
            }
            return FrameImage(id: uuidClient.create(), cgImage: cgImage)
        }
    }

    func add(customRunner runner: Runner, with frameImages: [FrameImage]) throws {
        let imageDataList = try frameImages.map {
            try dataClient.convert($0.cgImage, .png)
        }
        try saveFrameImageDataList(imageDataList, of: runner)
        let runners = applicationSupportRepository.loadCustomRunners()
        try applicationSupportRepository.saveCustomRunners(runners + [runner])
        loadRunnerBundleList()
    }

    func update(customRunner runner: Runner, with frameImages: [FrameImage]) throws {
        var runners = applicationSupportRepository.loadCustomRunners()
        guard let index = runners.firstIndex(of: runner) else {
            throw RCNError.customRunner(.loadingFailed)
        }
        let imageDataList = try frameImages.map {
            try dataClient.convert($0.cgImage, .png)
        }
        applicationSupportRepository.delete(directory: runner.id)
        try saveFrameImageDataList(imageDataList, of: runner)
        runners[index] = runner
        try applicationSupportRepository.saveCustomRunners(runners)
        if appStateClient.withLock(\.runnerBundles.latestValue)?.runner == runner {
            try update(runner: runner)
        }
        loadRunnerBundleList()
    }

    private func saveFrameImageDataList(_ imageDataList: [Data], of runner: Runner) throws {
        try imageDataList.enumerated().forEach { index, imageData in
            try applicationSupportRepository.saveData(
                directory: runner.id,
                fileName: "frame-\(index)",
                fileType: .png,
                data: imageData
            )
        }
    }

    func delete(customRunner runner: Runner) throws {
        var runners = applicationSupportRepository.loadCustomRunners()
        runners.removeAll { $0 == runner }
        try applicationSupportRepository.saveCustomRunners(runners)
        applicationSupportRepository.delete(directory: runner.id)
        loadRunnerBundleList()
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) throws {
        var runners = applicationSupportRepository.loadCustomRunners()
        runners.move(fromOffsets: source, toOffset: destination)
        try applicationSupportRepository.saveCustomRunners(runners)
        loadRunnerBundleList()
    }
}
