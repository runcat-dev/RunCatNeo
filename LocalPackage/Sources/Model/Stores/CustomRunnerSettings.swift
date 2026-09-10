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
    private let appStateClient: AppStateClient
    private let uuidClient: UUIDClient
    private let logService: LogService
    private let runnerService: RunnerService

    public var customRunnerBundleList: [RunnerBundle]
    public var customRunnerEditor: CustomRunnerEditor?
    public var showingGuidancePopover: Bool
    public let action: (Action) async -> Void

    public init(
        _ appDependencies: AppDependencies,
        customRunnerBundleList: [RunnerBundle] = [],
        customRunnerEditor: CustomRunnerEditor? = nil,
        showingGuidancePopover: Bool = false,
        action: @escaping (Action) async -> Void = { _ in }
    ) {
        self.appStateClient = appDependencies.appStateClient
        self.uuidClient = appDependencies.uuidClient
        self.logService = .init(appDependencies)
        self.runnerService = .init(appDependencies)
        self.customRunnerBundleList = customRunnerBundleList
        self.customRunnerEditor = customRunnerEditor
        self.showingGuidancePopover = showingGuidancePopover
        self.action = action
    }

    public func reduce(_ action: Action) async {
        switch action {
        case .viewAppeared:
            customRunnerBundleList = appStateClient.withLock(\.runnerBundleLists.latestValue)?
                .filter(\.runner.isCustom) ?? []

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
            } catch {
                logService.critical(.deletingCustomRunnerFailed(error))
            }

        case let .customRunnerRowMoved(indexSet, offset):
            customRunnerBundleList.move(fromOffsets: indexSet, toOffset: offset)
            do {
                try runnerService.move(fromOffsets: indexSet, toOffset: offset)
            } catch {
                logService.critical(.sortingCustomRunnersFailed(error))
            }

        case let .addCustomRunnerButtonTapped(appDependencies):
            customRunnerEditor = .init(
                appDependencies,
                id: uuidClient.create(),
                action: { [weak self] in
                    await self?.send(.customRunnerEditor($0))
                }
            )

        case .guidanceButtonTapped:
            showingGuidancePopover = true

        case .customRunnerEditor(.cancelButtonTapped):
            customRunnerEditor = nil

        case let .customRunnerEditor(.customRunnerAdded(runnerBundle)):
            customRunnerBundleList.append(runnerBundle)
            customRunnerEditor = nil

        case .customRunnerEditor:
            return
        }
    }

    public enum Action: Sendable {
        case viewAppeared
        case deleteButtonTapped(Runner)
        case customRunnerRowMoved(IndexSet, Int)
        case addCustomRunnerButtonTapped(AppDependencies)
        case guidanceButtonTapped
        case customRunnerEditor(CustomRunnerEditor.Action)
    }
}
