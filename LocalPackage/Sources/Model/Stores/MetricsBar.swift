/*
 MetricsBar.swift
 Model

 Created by Takuto Nakamura on 2026/05/24.
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
import SystemInfoKit

@MainActor @Observable
public final class MetricsBar: Composable {
    private let appStateClient: AppStateClient
    private let userDefaultsRepository: UserDefaultsRepository
    private let logService: LogService

    @ObservationIgnored private var task: Task<Void, Never>?

    public var metricsBarConfiguration: MetricsBarConfiguration
    public var systemInfoBundle: SystemInfoBundle
    public var customMetricsBundles: [CustomMetricsBundle]
    public var ipAddressInfo: IPAddressInfo
    public let isPreview: Bool
    public let action: (Action) async -> Void

    public init(
        _ appDependencies: AppDependencies,
        metricsBarConfiguration: MetricsBarConfiguration? = nil,
        systemInfoBundle: SystemInfoBundle = .init(),
        customMetricsBundles: [CustomMetricsBundle] = [],
        ipAddressInfo: IPAddressInfo = .init(),
        isPreview: Bool? = nil,
        action: @escaping (Action) async -> Void = { _ in }
    ) {
        self.appStateClient = appDependencies.appStateClient
        self.userDefaultsRepository = .init(appDependencies.userDefaultsClient)
        self.logService = .init(appDependencies)
        self.metricsBarConfiguration = metricsBarConfiguration ?? userDefaultsRepository.metricsBarConfiguration
        self.systemInfoBundle = systemInfoBundle
        self.customMetricsBundles = customMetricsBundles
        self.ipAddressInfo = ipAddressInfo
        self.isPreview = isPreview ?? ProcessInfo.isPreview
        self.action = action
    }

    public func reduce(_ action: Action) async {
        switch action {
        case let .task(screenName):
            logService.notice(.screenView(name: screenName))
            if let metrics = appStateClient.withLock(\.metrics.latestValue) {
                updateMetrics(from: metrics)
            }
            task?.cancel()
            task = Task.immediate { [weak self, appStateClient] in
                await withTaskGroup { group in
                    group.addImmediateTask {
                        let stream = appStateClient.withLock(\.metrics.stream)
                        for await value in stream {
                            self?.updateMetrics(from: value)
                        }
                    }
                    group.addImmediateTask {
                        let stream = appStateClient.withLock(\.systemMetricsConfigurationChanges.stream)
                        for await _ in stream {
                            self?.updateMetricsBarConfiguration()
                        }
                    }
                    group.addImmediateTask {
                        let stream = appStateClient.withLock(\.customMetricsConfigurationChanges.stream)
                        for await _ in stream {
                            self?.updateMetricsBarConfiguration()
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
        customMetricsBundles = metrics.customMetricsBundles
        ipAddressInfo = metrics.ipAddressInfo
    }

    private func updateMetricsBarConfiguration() {
        metricsBarConfiguration = userDefaultsRepository.metricsBarConfiguration
    }

    public enum Action: Sendable {
        case task(String)
        case onDisappear
    }
}
