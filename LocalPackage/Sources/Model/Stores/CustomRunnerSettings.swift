/*
 CustomRunnerSettings.swift
 Model

 Created by Takuto Nakamura on 2026/05/31.
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

import AppKit
import DataSource
import Foundation
import Observation

@MainActor @Observable
public final class CustomRunnerSettings: Composable {
    private let appStateClient: AppStateClient
    private let uuidClient: UUIDClient
    private let logService: LogService
    private let runnerService: RunnerService

    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var index = Int.zero

    public var customRunnerBundleList: [RunnerBundle]
    public var showingCustomRunnerEditorSheet: Bool
    public var runnerName: String
    public var isTemplate: Bool
    public var frameImages: [FrameImage]
    public var selectingFrameImage: FrameImage?
    public var previewingFrameImage: FrameImage?
    public var previewSpeed: Double
    public var showingFileImporter: Bool
    public let action: (Action) async -> Void

    public var canAdd: Bool {
        !runnerName.isEmpty && !frameImages.isEmpty
    }

    public init(
        _ appDependencies: AppDependencies,
        customRunnerBundleList: [RunnerBundle] = [],
        showingCustomRunnerEditorSheet: Bool = false,
        runnerName: String = "",
        isTemplate: Bool = true,
        frameImages: [FrameImage] = [],
        selectingFrameImage: FrameImage? = nil,
        previewingFrameImage: FrameImage? = nil,
        previewSpeed: Double = 1,
        showingFileImporter: Bool = false,
        action: @escaping (Action) async -> Void =  { _ in }
    ) {
        self.appStateClient = appDependencies.appStateClient
        self.uuidClient = appDependencies.uuidClient
        self.logService = .init(appDependencies)
        self.runnerService = .init(appDependencies)
        self.customRunnerBundleList = customRunnerBundleList
        self.showingCustomRunnerEditorSheet = showingCustomRunnerEditorSheet
        self.runnerName = runnerName
        self.isTemplate = isTemplate
        self.frameImages = frameImages
        self.selectingFrameImage = selectingFrameImage
        self.previewingFrameImage = previewingFrameImage
        self.previewSpeed = previewSpeed
        self.showingFileImporter = showingFileImporter
        self.action = action
    }

    public func reduce(_ action: Action) async {
        switch action {
        case .task:
            customRunnerBundleList = appStateClient.withLock(\.runnerBundleLists.latestValue)?
                .filter(\.runner.isCustom) ?? []
            task?.cancel()
            task = Task { [weak self] in
                while !Task.isCancelled {
                    guard let self else { break }
                    advanceFrameImage()
                    try? await Task.sleep(for: .seconds(0.2 - 0.05 * previewSpeed))
                }
            }
            
        case .onDisappear:
            task?.cancel()
            task = nil
            
        case .addCustomRunnerButtonTapped:
            showingCustomRunnerEditorSheet = true
            
        case .cancelButtonTapped:
            showingCustomRunnerEditorSheet = false
            
        case .onDissmissSheet:
            runnerName = ""
            isTemplate = true
            frameImages.removeAll()
            selectingFrameImage = nil
            previewingFrameImage = nil
            previewSpeed = 1

        case let .deleteButtonTapped(runner):
            guard let currentRunner = appStateClient.withLock(\.runnerBundles.latestValue)?.runner else {
                return
            }
            do {
                guard currentRunner != runner else {
                    throw RCNError.customRunner(.runnerInUse)
                }
                customRunnerBundleList.removeAll { $0.runner == runner }
                try runnerService.delete(customRunner: runner)
            } catch let error as RCNError {
                await send(.onError(error))
            } catch {
                logService.critical(.deletingCustomRunnerFailed(error))
            }

        case let .selectRenderingMode(renderingMode):
            isTemplate = renderingMode.isTemplate

        case let .onDragFrameImageCell(frameImage):
            selectingFrameImage = frameImage
            
        case let .onTapFrameImageCell(frameImage):
            selectingFrameImage = frameImage
            
        case .onTapCollectionBackground:
            selectingFrameImage = nil
            
        case let .onDropCollection(urls):
            do {
                try urls.forEach { url in
                    if url.pathExtension.lowercased() == "png" {
                        try appendFrameImage(from: url)
                    }
                }
            } catch let error as RCNError {
                await send(.onError(error))
            } catch {
                logService.error(.importingFrameImagesFailed(error))
            }
            
        case .addFrameButtonTapped:
            showingFileImporter = true
            
        case .deleteFrameButtonTapped:
            guard let frameImage = selectingFrameImage,
                  let index = frameImages.firstIndex(of: frameImage) else {
                return
            }
            frameImages.remove(at: index)
            selectingFrameImage = if index < frameImages.count {
                frameImages[index]
            } else {
                frameImages.last
            }
            advanceFrameImage()
            
        case let .onCompletionFileImporter(.success(urls)):
            do {
                for url in urls {
                    guard url.startAccessingSecurityScopedResource() else { return }
                    defer {
                        url.stopAccessingSecurityScopedResource()
                    }
                    try appendFrameImage(from: url)
                }
            } catch let error as RCNError {
                await send(.onError(error))
            } catch {
                logService.error(.importingFrameImagesFailed(error))
            }
            
        case let .onCompletionFileImporter(.failure(error)):
            logService.error(.importingFrameImagesFailed(error))
            
        case .addButtonTapped:
            guard let frameImage = frameImages.first else { return }
            do {
                guard runnerService.validate(customRunnerName: runnerName) else {
                    throw RCNError.customRunner(.nameAlreadyExists)
                }
                let runner = Runner(
                    id: uuidClient.create().uuidString,
                    name: runnerName,
                    isTemplate: isTemplate,
                    frameOrder: .custom(frameImages.indices.map(\.self))
                )
                do {
                    let frame = try runnerService.convertToCustomFrame(from: frameImage)
                    try runnerService.save(customRunner: runner, with: frameImages)
                    customRunnerBundleList.append(.init(runner: runner, frame: frame))
                } catch {
                    logService.critical(.savingCustomRunnerFailed(error))
                    throw RCNError.customRunner(.savingFailed)
                }
                showingCustomRunnerEditorSheet = false
            } catch let error as RCNError {
                await send(.onError(error))
            } catch {
                logService.critical(.unknown(error))
            }
            
        case .onError:
            return
        }
    }

    private func advanceFrameImage() {
        if frameImages.isEmpty {
            previewingFrameImage = nil
        } else {
            index = min(frameImages.count - 1, (index + 1) % frameImages.count)
            previewingFrameImage = frameImages[index]
        }
    }

    private func appendFrameImage(from url: URL) throws {
        guard let nsImage = NSImage(contentsOf: url),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil),
              cgImage.height == 36,
              (10 ... 100).contains(cgImage.width) else {
            throw RCNError.customRunner(.invalidFrameImage)
        }
        guard frameImages.count <= 30 else {
            throw RCNError.customRunner(.frameLimitExceeded)
        }
        frameImages.append(.init(id: uuidClient.create(), cgImage: cgImage))
    }

    public enum Action: Sendable {
        case task
        case onDisappear
        case deleteButtonTapped(Runner)
        case addCustomRunnerButtonTapped
        case cancelButtonTapped
        case onDissmissSheet
        case selectRenderingMode(RenderingMode)
        case onDragFrameImageCell(FrameImage)
        case onTapFrameImageCell(FrameImage)
        case onTapCollectionBackground
        case onDropCollection([URL])
        case addFrameButtonTapped
        case deleteFrameButtonTapped
        case onCompletionFileImporter(Result<[URL], any Error>)
        case addButtonTapped
        case onError(RCNError)
    }
}
