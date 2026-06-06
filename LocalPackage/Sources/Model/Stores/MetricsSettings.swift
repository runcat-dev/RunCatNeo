/*
 MetricsSettings.swift
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
import Foundation
import Observation
import SystemInfoKit

@MainActor @Observable
public final class MetricsSettings: Composable {
    private let appStateClient: AppStateClient
    private let userDefaultsRepository: UserDefaultsRepository
    private let nsWorkspaceClient: NSWorkspaceClient
    private let customMetricsService: CustomMetricsService
    private let logService: LogService
    private let systemMetricsService: SystemMetricsService

    @ObservationIgnored private var task: Task<Void, Never>?

    public var systemMetricsConfiguration: SystemMetricsConfiguration
    public var customMetricsSources: [CustomMetricsSource]
    public var failedCustomMetricsSourceIDs: Set<UUID>
    public var showingFileImporter: Bool
    public var showingConfirmationDialog: Bool
    public var pendingRemovalSourceID: UUID?
    public let action: (Action) async -> Void

    public var customMetricsSchemaURL: URL? {
        URL(string: .gitHubURL)?.appending(path: "blob/main/docs/CustomMetricsSchema.md")
    }

    public init(
        _ appDependencies: AppDependencies,
        systemMetricsConfiguration: SystemMetricsConfiguration? = nil,
        customMetricsSources: [CustomMetricsSource]? = nil,
        failedCustomMetricsSourceIDs: Set<UUID> = [],
        showingFileImporter: Bool = false,
        showingConfirmationDialog: Bool = false,
        pendingRemovalSourceID: UUID? = nil,
        action: @escaping (Action) async -> Void = { _ in }
    ) {
        self.appStateClient = appDependencies.appStateClient
        self.userDefaultsRepository = .init(appDependencies.userDefaultsClient)
        self.nsWorkspaceClient = appDependencies.nsWorkspaceClient
        self.customMetricsService = .init(appDependencies)
        self.logService = .init(appDependencies)
        self.systemMetricsService = .init(appDependencies)
        self.systemMetricsConfiguration = systemMetricsConfiguration ?? userDefaultsRepository.systemMetricsConfiguration
        self.customMetricsSources = customMetricsSources ?? userDefaultsRepository.customMetricsConfiguration.sources
        self.failedCustomMetricsSourceIDs = failedCustomMetricsSourceIDs
        self.showingFileImporter = showingFileImporter
        self.showingConfirmationDialog = showingConfirmationDialog
        self.pendingRemovalSourceID = pendingRemovalSourceID
        self.action = action
    }

    public func reduce(_ action: Action) async {
        switch action {
        case let .task(screenName):
            logService.notice(.screenView(name: screenName))
            customMetricsSources = userDefaultsRepository.customMetricsConfiguration.sources
            refreshFailedCustomMetricsSourceIDs()
            task?.cancel()
            task = Task { [weak self, appStateClient] in
                await withTaskGroup { group in
                    group.addTask {
                        let stream = appStateClient.withLock(\.systemMetricsConfigurationChanges.stream)
                        for await _ in stream {
                            await self?.refreshSystemMetricsConfiguration()
                        }
                    }
                    group.addTask {
                        let stream = appStateClient.withLock(\.metrics.stream)
                        for await _ in stream {
                            await self?.refreshFailedCustomMetricsSourceIDs()
                        }
                    }
                }
            }

        case .onDisappear:
            task?.cancel()
            task = nil

        case let .monitorsSystemInfoToggleSwitched(type, isOn):
            func overwrite(isOn: Bool, shows: inout Bool) {
                shows = shows && isOn
            }
            var metricsBarConfiguration = userDefaultsRepository.metricsBarConfiguration
            switch type {
            case .cpu:
                return
            case .memory:
                systemMetricsConfiguration.monitorsMemory = isOn
                overwrite(isOn: isOn, shows: &metricsBarConfiguration.showsMemory)
            case .storage:
                systemMetricsConfiguration.monitorsStorage = isOn
                overwrite(isOn: isOn, shows: &metricsBarConfiguration.showsStorage)
            case .battery:
                systemMetricsConfiguration.monitorsBattery = isOn
                overwrite(isOn: isOn, shows: &metricsBarConfiguration.showsBattery)
            case .network:
                systemMetricsConfiguration.monitorsNetwork = isOn
                overwrite(isOn: isOn, shows: &metricsBarConfiguration.showsNetwork)
            }
            userDefaultsRepository.systemMetricsConfiguration = systemMetricsConfiguration
            userDefaultsRepository.metricsBarConfiguration = metricsBarConfiguration
            systemMetricsService.toggleSystemInfoActivation(type: type, isOn: isOn)
            systemMetricsService.emitConfigurationChange()

        case .addCustomMetricsSourceButtonTapped:
            showingFileImporter = true

        case let .onCompletionFileImporter(.success(url)):
            do {
                try customMetricsService.addSource(of: url)
                customMetricsSources = userDefaultsRepository.customMetricsConfiguration.sources
                customMetricsService.emitConfigurationChange()
            } catch let error as RCNError {
                print(error.localizedDescription)
            } catch {
                logService.critical(.unknown(error))
            }

        case let .onCompletionFileImporter(.failure(error)):
            logService.critical(.unknown(error))

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
                logService.critical(.unknown(error))
            }
        }
    }

    private func refreshSystemMetricsConfiguration() {
        systemMetricsConfiguration = userDefaultsRepository.systemMetricsConfiguration
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
        case task(String)
        case onDisappear
        case monitorsSystemInfoToggleSwitched(SystemInfoType, Bool)
        case addCustomMetricsSourceButtonTapped
        case onCompletionFileImporter(Result<URL, any Error>)
        case removeCustomMetricsSourceButtonTapped(UUID)
        case removingCustomMetricsSourceConfirmed
        case removingCustomMetricsSourceCancelled
        case customMetricsSourceLinkTapped(CustomMetricsSource)
    }
}
