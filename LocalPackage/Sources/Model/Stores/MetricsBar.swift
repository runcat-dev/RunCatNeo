/*
 MetricsBar.swift
 Model

 Created by Takuto Nakamura on 2026/05/24.
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
public final class MetricsBar: Composable {
    private let appStateClient: AppStateClient
    private let userDefaultsRepository: UserDefaultsRepository
    private let logService: LogService

    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var customMetricsSourceIDs = [UUID]()

    public var metricsBarConfiguration: MetricsBarConfiguration
    public var systemInfoBundle: SystemInfoBundle
    public var customMetricsBundles: [CustomMetricsBundle]
    public let action: (Action) async -> Void

    public init(
        _ appDependencies: AppDependencies,
        metricsBarConfiguration: MetricsBarConfiguration? = nil,
        systemInfoBundle: SystemInfoBundle = .init(),
        customMetricsBundles: [CustomMetricsBundle] = [],
        action: @escaping (Action) async -> Void = { _ in }
    ) {
        self.appStateClient = appDependencies.appStateClient
        self.userDefaultsRepository = .init(appDependencies.userDefaultsClient)
        self.logService = .init(appDependencies)
        self.metricsBarConfiguration = metricsBarConfiguration ?? userDefaultsRepository.metricsBarConfiguration
        self.systemInfoBundle = systemInfoBundle
        self.customMetricsBundles = customMetricsBundles
        self.action = action
    }

    public func reduce(_ action: Action) async {
        switch action {
        case let .task(screenName):
            logService.notice(.screenView(name: screenName))
            customMetricsSourceIDs = userDefaultsRepository.customMetricsConfiguration.sources.map(\.id)
            if let metrics = appStateClient.withLock(\.metrics.latestValue) {
                updateMetrics(from: metrics)
            }
            task?.cancel()
            task = Task { [weak self, appStateClient] in
                await withTaskGroup { group in
                    group.addTask {
                        let stream = appStateClient.withLock(\.metrics.stream)
                        for await value in stream {
                            await self?.updateMetrics(from: value)
                        }
                    }
                    group.addTask {
                        let stream = appStateClient.withLock(\.systemMetricsConfigurationChanges.stream)
                        for await _ in stream {
                            await self?.updateMetricsBarConfiguration()
                        }
                    }
                    group.addTask {
                        let stream = appStateClient.withLock(\.customMetricsConfigurationChanges.stream)
                        for await _ in stream {
                            await self?.updateCustomMetricsConfiguration()
                        }
                    }
                }
            }

        case .onDisappear:
            task?.cancel()
            task = nil
        }
    }

    private func updateMetrics(from metrics: Metrics) {
        systemInfoBundle = metrics.systemInfoBundle
        customMetricsBundles = sortedBySourceOrder(metrics.customMetricsBundles)
    }

    private func updateMetricsBarConfiguration() {
        metricsBarConfiguration = userDefaultsRepository.metricsBarConfiguration
    }

    private func updateCustomMetricsConfiguration() {
        customMetricsSourceIDs = userDefaultsRepository.customMetricsConfiguration.sources.map(\.id)
        metricsBarConfiguration = userDefaultsRepository.metricsBarConfiguration
        customMetricsBundles = sortedBySourceOrder(customMetricsBundles)
    }

    private func sortedBySourceOrder(_ bundles: [CustomMetricsBundle]) -> [CustomMetricsBundle] {
        customMetricsSourceIDs.compactMap { id in
            bundles.first { $0.id == id }
        }
    }

    public enum Action: Sendable {
        case task(String)
        case onDisappear
    }
}
