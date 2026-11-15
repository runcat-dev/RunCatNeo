/*
 Dashboard.swift
 Model

 Created by Takuto Nakamura on 2026/05/08.
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
public final class Dashboard: Composable {
    private let appStateClient: AppStateClient
    private let dateClient: DateClient
    private let batteryHealthService: BatteryHealthService
    private let logService: LogService

    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var batteryHealthTask: Task<Void, Never>?

    public var appName: String
    public var systemInfoBundle: SystemInfoBundle
    public private(set) var maximumBatteryCapacityPercent: Double?
    public var cpuRingBuffer: RingBuffer
    public var memoryRingBuffer: RingBuffer
    public var customMetricsBundles: [CustomMetricsBundle]
    public var displayedDate: Date
    public let isPreview: Bool
    public let dashboardMenu: DashboardMenu
    public let action: (Action) async -> Void

    public init(
        _ appDependencies: AppDependencies,
        appName: String? = nil,
        systemInfoBundle: SystemInfoBundle = .cpuZero(),
        cpuRingBuffer: RingBuffer = .init(),
        memoryRingBuffer: RingBuffer = .init(),
        customMetricsBundles: [CustomMetricsBundle] = [],
        displayedDate: Date? = nil,
        isPreview: Bool? = nil,
        dashboardMenu: DashboardMenu? = nil,
        action: @escaping (Action) async -> Void =  { _ in }
    ) {
        self.appStateClient = appDependencies.appStateClient
        self.dateClient = appDependencies.dateClient
        self.batteryHealthService = .init(appDependencies)
        self.logService = .init(appDependencies)
        self.appName = appName ?? appStateClient.withLock(\.name)
        self.systemInfoBundle = systemInfoBundle
        self.cpuRingBuffer = cpuRingBuffer
        self.memoryRingBuffer = memoryRingBuffer
        self.customMetricsBundles = customMetricsBundles
        self.displayedDate = displayedDate ?? dateClient.now()
        self.isPreview = isPreview ?? ProcessInfo.isPreview
        weak var weakSelf: Dashboard? = nil
        self.dashboardMenu = dashboardMenu ??
            .init(appDependencies, action: { await weakSelf?.send(.dashboardMenu($0)) })
        self.action = action
        weakSelf = self
    }

    deinit {
        batteryHealthTask?.cancel()
    }

    public func reduce(_ action: Action) async {
        switch action {
        case let .viewAppeared(screenName):
            logService.notice(.screenView(name: screenName))
            displayedDate = dateClient.now()
            if let metrics = appStateClient.withLock(\.metrics.latestValue) {
                updateMetrics(metrics)
            }
            updateBatteryHealthMonitoring()
            task?.cancel()
            task = Task.immediate { [weak self, appStateClient] in
                let stream = appStateClient.withLock(\.metrics.stream)
                for await value in stream {
                    guard !Task.isCancelled else { return }
                    self?.updateMetrics(value)
                }
            }

        case .viewDisappeared:
            task?.cancel()
            task = nil
            batteryHealthTask?.cancel()
            batteryHealthTask = nil

        case .dashboardMenu:
            return
        }
    }

    private func updateMetrics(_ metrics: Metrics) {
        systemInfoBundle = metrics.systemInfoBundle
        cpuRingBuffer = metrics.cpuRingBuffer
        memoryRingBuffer = metrics.memoryRingBuffer
        customMetricsBundles = metrics.customMetricsBundles
        updateBatteryHealthMonitoring()
    }

    private func updateBatteryHealthMonitoring() {
        guard !isPreview, systemInfoBundle.batteryInfo?.isInstalled == true else {
            batteryHealthTask?.cancel()
            batteryHealthTask = nil
            maximumBatteryCapacityPercent = nil
            return
        }
        guard batteryHealthTask == nil else { return }
        batteryHealthTask = Task { [weak self, batteryHealthService] in
            while !Task.isCancelled {
                let value = await batteryHealthService.maximumCapacityPercent()
                guard !Task.isCancelled, self != nil else { return }
                self?.maximumBatteryCapacityPercent = value
                do {
                    try await Task.sleep(for: .seconds(value == nil ? 30 : 300))
                } catch {
                    return
                }
            }
        }
    }

    public enum Action: Sendable {
        case viewAppeared(String)
        case viewDisappeared
        case dashboardMenu(DashboardMenu.Action)
    }
}
