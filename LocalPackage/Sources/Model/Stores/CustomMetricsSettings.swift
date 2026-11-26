/*
 CustomMetricsSettings.swift
 Model

 Created by Takuto Nakamura on 2026/06/09.
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
import Observation

@MainActor @Observable
public final class CustomMetricsSettings: Composable {
    private let appDependencies: AppDependencies
    private let appStateClient: AppStateClient
    private let uuidClient: UUIDClient
    private let userDefaultsRepository: UserDefaultsRepository
    private let nsWorkspaceClient: NSWorkspaceClient
    private let customMetricsService: CustomMetricsService

    @ObservationIgnored private var task: Task<Void, Never>?

    public var customMetricsSources: [CustomMetricsSource]
    public var failedCustomMetricsSourceIDs: Set<UUID>
    public var customMetricsSourceEditor: CustomMetricsSourceEditor?
    public var showingConfirmationDialog: Bool
    public var pendingRemovalSourceID: UUID?
    public var showingGuidancePopover: Bool
    public var showingAlert: Bool
    public var error: RCNError?
    public let action: (Action) async -> Void

    public init(
        _ appDependencies: AppDependencies,
        customMetricsSources: [CustomMetricsSource]? = nil,
        failedCustomMetricsSourceIDs: Set<UUID> = [],
        customMetricsSourceEditor: CustomMetricsSourceEditor? = nil,
        showingConfirmationDialog: Bool = false,
        pendingRemovalSourceID: UUID? = nil,
        showingGuidancePopover: Bool = false,
        showingAlert: Bool = false,
        error: RCNError? = nil,
        action: @escaping (Action) async -> Void = { _ in }
    ) {
        self.appDependencies = appDependencies
        self.appStateClient = appDependencies.appStateClient
        self.uuidClient = appDependencies.uuidClient
        self.userDefaultsRepository = .init(appDependencies.userDefaultsClient)
        self.nsWorkspaceClient = appDependencies.nsWorkspaceClient
        self.customMetricsService = .init(appDependencies)
        self.customMetricsSources = customMetricsSources ?? userDefaultsRepository.customMetricsConfiguration.sources
        self.failedCustomMetricsSourceIDs = failedCustomMetricsSourceIDs
        self.customMetricsSourceEditor = customMetricsSourceEditor
        self.showingConfirmationDialog = showingConfirmationDialog
        self.pendingRemovalSourceID = pendingRemovalSourceID
        self.showingGuidancePopover = showingGuidancePopover
        self.showingAlert = showingAlert
        self.error = error
        self.action = action
    }

    public func reduce(_ action: Action) async {
        switch action {
        case .viewAppeared:
            customMetricsSources = userDefaultsRepository.customMetricsConfiguration.sources
            refreshFailedCustomMetricsSourceIDs()
            task?.cancel()
            task = Task.immediate { [weak self, appStateClient] in
                let stream = appStateClient.withLock(\.metrics.stream)
                for await _ in stream {
                    self?.refreshFailedCustomMetricsSourceIDs()
                }
            }

        case .viewDisappeared:
            task?.cancel()
            task = nil

        case let .removeCustomMetricsSourceButtonTapped(id):
            pendingRemovalSourceID = id
            showingConfirmationDialog = true

        case let .editCustomMetricsSourceButtonTapped(source):
            customMetricsSourceEditor = .init(
                appDependencies,
                id: uuidClient.create(),
                editingSource: source,
                source: source,
                snapshot: appStateClient.withLock(\.metrics.latestValue)?.customMetricsBundles
                    .first { $0.id == source.id }?
                    .snapshot,
                symbolImageData: customMetricsService.savedSymbolImageData(of: source.id),
                action: { [weak self] in
                    await self?.send(.customMetricsSourceEditor($0))
                }
            )

        case let .customMetricsSourceLinkTapped(source):
            do {
                try customMetricsService.perform(
                    action: { nsWorkspaceClient.activateFileViewerSelecting([$0]) },
                    for: source
                )
            } catch {
                await send(.errorOccurred(.customMetrics(.fileUnreadable)))
            }

        case let .customMetricsSourceRowMoved(indexSet, offset):
            customMetricsService.moveSources(fromOffsets: indexSet, toOffset: offset)
            customMetricsSources = userDefaultsRepository.customMetricsConfiguration.sources
            customMetricsService.emitConfigurationChange()

        case .addCustomMetricsSourceButtonTapped:
            customMetricsSourceEditor = .init(
                appDependencies,
                id: uuidClient.create(),
                action: { [weak self] in
                    await self?.send(.customMetricsSourceEditor($0))
                }
            )

        case .removingCustomMetricsSourceConfirmed:
            guard let sourceID = pendingRemovalSourceID else { return }
            customMetricsService.removeSource(of: sourceID)
            customMetricsSources = userDefaultsRepository.customMetricsConfiguration.sources
            customMetricsService.emitConfigurationChange()
            pendingRemovalSourceID = nil

        case .removingCustomMetricsSourceCancelled:
            pendingRemovalSourceID = nil

        case .guidanceButtonTapped:
            showingGuidancePopover = true

        case .customMetricsSourceEditor(.cancelButtonTapped):
            customMetricsSourceEditor = nil

        case .customMetricsSourceEditor(.customMetricsSourceAdded),
             .customMetricsSourceEditor(.customMetricsSourceUpdated):
            customMetricsSources = userDefaultsRepository.customMetricsConfiguration.sources
            customMetricsService.emitConfigurationChange()
            customMetricsSourceEditor = nil

        case .customMetricsSourceEditor:
            return

        case let .errorOccurred(error):
            self.error = error
            showingAlert = true
        }
    }

    private func refreshFailedCustomMetricsSourceIDs() {
        guard let metrics = appStateClient.withLock(\.metrics.latestValue) else {
            return
        }
        failedCustomMetricsSourceIDs = metrics.customMetricsBundles.reduce(into: Set<UUID>()) {
            if $1.isFailed {
                $0.insert($1.id)
            }
        }
    }

    public enum Action: Sendable {
        case viewAppeared
        case viewDisappeared
        case removeCustomMetricsSourceButtonTapped(UUID)
        case editCustomMetricsSourceButtonTapped(CustomMetricsSource)
        case customMetricsSourceLinkTapped(CustomMetricsSource)
        case customMetricsSourceRowMoved(IndexSet, Int)
        case addCustomMetricsSourceButtonTapped
        case removingCustomMetricsSourceConfirmed
        case removingCustomMetricsSourceCancelled
        case guidanceButtonTapped
        case customMetricsSourceEditor(CustomMetricsSourceEditor.Action)
        case errorOccurred(RCNError)
    }
}
