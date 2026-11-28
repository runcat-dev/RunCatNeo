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
import Observation

@MainActor @Observable
public final class CustomRunnerSettings: Composable {
    private let appDependencies: AppDependencies
    private let appStateClient: AppStateClient
    private let urlClient: URLClient
    private let uuidClient: UUIDClient
    private let logService: LogService
    private let runnerService: RunnerService
    private let archivedRunnerService: ArchivedRunnerService

    public var customRunnerBundleList: [RunnerBundle]
    public var customRunnerEditor: CustomRunnerEditor?
    public var showingGuidancePopover: Bool
    public var showingFileImporter: Bool
    public var showingAlert: Bool
    public var error: RCNError?
    public let action: (Action) async -> Void

    public init(
        _ appDependencies: AppDependencies,
        customRunnerBundleList: [RunnerBundle] = [],
        customRunnerEditor: CustomRunnerEditor? = nil,
        showingGuidancePopover: Bool = false,
        showingFileImporter: Bool = false,
        showingAlert: Bool = false,
        error: RCNError? = nil,
        action: @escaping (Action) async -> Void = { _ in }
    ) {
        self.appDependencies = appDependencies
        self.appStateClient = appDependencies.appStateClient
        self.urlClient = appDependencies.urlClient
        self.uuidClient = appDependencies.uuidClient
        self.logService = .init(appDependencies)
        self.runnerService = .init(appDependencies)
        self.archivedRunnerService = .init(appDependencies)
        self.customRunnerBundleList = customRunnerBundleList
        self.customRunnerEditor = customRunnerEditor
        self.showingGuidancePopover = showingGuidancePopover
        self.showingFileImporter = showingFileImporter
        self.showingAlert = showingAlert
        self.error = error
        self.action = action
    }

    public func reduce(_ action: Action) async {
        switch action {
        case .viewAppeared:
            customRunnerBundleList = appStateClient.withLock(\.runnerBundleLists.latestValue)?
                .filter(\.runner.isCustom) ?? []

        case let .removeCustomRunnerButtonTapped(runner):
            guard let currentRunner = appStateClient.withLock(\.runnerBundles.latestValue)?.runner else {
                return
            }
            do {
                guard currentRunner.id != runner.id else {
                    throw RCNError.customRunner(.runnerInUse)
                }
                customRunnerBundleList.removeAll { $0.id == runner.id }
                try runnerService.delete(customRunner: runner)
            } catch let error as RCNError {
                await send(.errorOccurred(error))
            } catch {
                logService.critical(.deletingCustomRunnerFailed(error))
            }

        case let .editCustomRunnerButtonTapped(runner):
            guard case let .custom(name) = runner.source else { return }
            do {
                let frameImages = try runnerService.loadFrameImages(of: runner)
                customRunnerEditor = .init(
                    appDependencies,
                    id: uuidClient.create(),
                    mode: .edit(runner),
                    runnerName: name,
                    isTemplate: runner.isTemplate,
                    frameImages: frameImages,
                    action: { [weak self] in
                        await self?.send(.customRunnerEditor($0))
                    }
                )
            } catch let error as RCNError {
                await send(.errorOccurred(error))
            } catch {
                logService.critical(.unknown(error))
            }

        case let .customRunnerRowMoved(indexSet, offset):
            customRunnerBundleList.move(fromOffsets: indexSet, toOffset: offset)
            do {
                try runnerService.move(fromOffsets: indexSet, toOffset: offset)
            } catch {
                logService.critical(.sortingCustomRunnersFailed(error))
            }

        case .addCustomRunnerButtonTapped:
            customRunnerEditor = .init(
                appDependencies,
                id: uuidClient.create(),
                action: { [weak self] in
                    await self?.send(.customRunnerEditor($0))
                }
            )

        case .importRunnerArchiveButtonTapped:
            showingFileImporter = true

        case let .fileImporterResponse(.success(url)):
            guard urlClient.startAccessingSecurityScopedResource(url) else { return }
            defer {
                urlClient.stopAccessingSecurityScopedResource(url)
            }
            do {
                let archivedRunner = try archivedRunnerService.unarchive(
                    from: url,
                    languageCode: Bundle.main.preferredLocalizations.first
                )
                customRunnerEditor = .init(
                    appDependencies,
                    id: uuidClient.create(),
                    runnerName: archivedRunner.runnerName,
                    isTemplate: archivedRunner.isTemplate,
                    frameImages: archivedRunner.frameImages,
                    action: { [weak self] in
                        await self?.send(.customRunnerEditor($0))
                    }
                )
            } catch let error as RCNError {
                await send(.errorOccurred(error))
            } catch {
                logService.error(.importingRunnerArchiveFailed(error))
            }

        case let .fileImporterResponse(.failure(error)):
            logService.error(.importingRunnerArchiveFailed(error))

        case .guidanceButtonTapped:
            showingGuidancePopover = true

        case .customRunnerEditor(.cancelButtonTapped):
            customRunnerEditor = nil

        case let .customRunnerEditor(.customRunnerSaved(runnerBundle)):
            if let index = customRunnerBundleList.firstIndex(where: { $0.id == runnerBundle.id }) {
                customRunnerBundleList[index] = runnerBundle
            } else {
                customRunnerBundleList.append(runnerBundle)
            }
            customRunnerEditor = nil

        case .customRunnerEditor:
            return

        case let .errorOccurred(error):
            self.error = error
            showingAlert = true
        }
    }

    public enum Action: Sendable {
        case viewAppeared
        case removeCustomRunnerButtonTapped(Runner)
        case editCustomRunnerButtonTapped(Runner)
        case customRunnerRowMoved(IndexSet, Int)
        case addCustomRunnerButtonTapped
        case importRunnerArchiveButtonTapped
        case fileImporterResponse(Result<URL, any Error>)
        case guidanceButtonTapped
        case customRunnerEditor(CustomRunnerEditor.Action)
        case errorOccurred(RCNError)
    }
}
