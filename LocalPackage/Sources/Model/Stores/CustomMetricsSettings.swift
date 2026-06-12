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
    private let appStateClient: AppStateClient
    private let userDefaultsRepository: UserDefaultsRepository
    private let nsWorkspaceClient: NSWorkspaceClient
    private let customMetricsService: CustomMetricsService
    private let logService: LogService

    @ObservationIgnored private var task: Task<Void, Never>?

    public var customMetricsSources: [CustomMetricsSource]
    public var failedCustomMetricsSourceIDs: Set<UUID>
    public var showingFileImporter: Bool
    public var showingConfirmationDialog: Bool
    public var pendingRemovalSourceID: UUID?
    public var showingHelpPopover: Bool
    public let action: (Action) async -> Void

    public init(
        _ appDependencies: AppDependencies,
        customMetricsSources: [CustomMetricsSource]? = nil,
        failedCustomMetricsSourceIDs: Set<UUID> = [],
        showingFileImporter: Bool = false,
        showingConfirmationDialog: Bool = false,
        pendingRemovalSourceID: UUID? = nil,
        showingHelpPopover: Bool = false,
        action: @escaping (Action) async -> Void = { _ in }
    ) {
        self.appStateClient = appDependencies.appStateClient
        self.userDefaultsRepository = .init(appDependencies.userDefaultsClient)
        self.nsWorkspaceClient = appDependencies.nsWorkspaceClient
        self.customMetricsService = .init(appDependencies)
        self.logService = .init(appDependencies)
        self.customMetricsSources = customMetricsSources ?? userDefaultsRepository.customMetricsConfiguration.sources
        self.failedCustomMetricsSourceIDs = failedCustomMetricsSourceIDs
        self.showingFileImporter = showingFileImporter
        self.showingConfirmationDialog = showingConfirmationDialog
        self.pendingRemovalSourceID = pendingRemovalSourceID
        self.showingHelpPopover = showingHelpPopover
        self.action = action
    }

    public func reduce(_ action: Action) async {
        switch action {
        case .task:
            customMetricsSources = userDefaultsRepository.customMetricsConfiguration.sources
            refreshFailedCustomMetricsSourceIDs()
            task?.cancel()
            task = Task { [weak self, appStateClient] in
                let stream = appStateClient.withLock(\.metrics.stream)
                for await _ in stream {
                    self?.refreshFailedCustomMetricsSourceIDs()
                }
            }

        case .onDisappear:
            task?.cancel()
            task = nil

        case .addCustomMetricsSourceButtonTapped:
            showingFileImporter = true

        case .helpButtonTapped:
            showingHelpPopover = true

        case let .onCompletionFileImporter(.success(url)):
            do {
                try customMetricsService.addSource(of: url)
                customMetricsSources = userDefaultsRepository.customMetricsConfiguration.sources
                customMetricsService.emitConfigurationChange()
            } catch let error as RCNError {
                await send(.onError(error))
            } catch {
                logService.critical(.unknown(error))
            }

        case let .onCompletionFileImporter(.failure(error)):
            logService.error(.importingCustomMetricsSourceFailed(error))

        case let .removeCustomMetricsSourceButtonTapped(id):
            pendingRemovalSourceID = id
            showingConfirmationDialog = true

        case .removingCustomMetricsSourceConfirmed:
            guard let sourceID = pendingRemovalSourceID else { return }
            customMetricsService.removeSource(of: sourceID)
            customMetricsSources = userDefaultsRepository.customMetricsConfiguration.sources
            customMetricsService.emitConfigurationChange()
            pendingRemovalSourceID = nil

        case .removingCustomMetricsSourceCancelled:
            pendingRemovalSourceID = nil

        case let .customMetricsSourceLinkTapped(source):
            do {
                try customMetricsService.perform(
                    action: { nsWorkspaceClient.activateFileViewerSelecting([$0]) },
                    for: source
                )
            } catch {
                await send(.onError(.customMetrics(.fileUnreadable)))
            }

        case .onError:
            return
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
        case task
        case onDisappear
        case addCustomMetricsSourceButtonTapped
        case helpButtonTapped
        case onCompletionFileImporter(Result<URL, any Error>)
        case removeCustomMetricsSourceButtonTapped(UUID)
        case removingCustomMetricsSourceConfirmed
        case removingCustomMetricsSourceCancelled
        case customMetricsSourceLinkTapped(CustomMetricsSource)
        case onError(RCNError)
    }
}
