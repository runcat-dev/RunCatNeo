/*
 Dashboard.swift
 Model

 Created by Takuto Nakamura on 2026/05/08.
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

import AppKit
import DataSource
import Foundation
import Observation
import SystemInfoKit

@MainActor @Observable
public final class Dashboard: Composable {
    private let appStateClient: AppStateClient
    private let nsAppClient: NSAppClient
    private let nsWorkspaceClient: NSWorkspaceClient
    private let userDefaultsRepository: UserDefaultsRepository
    private let logService: LogService

    @ObservationIgnored private var task: Task<Void, Never>?

    public var appName: String
    public var systemInfoBundle: SystemInfoBundle
    public var cpuRingBuffer: RingBuffer
    public var memoryRingBuffer: RingBuffer
    public var customMetricsBundles: [CustomMetricsBundle]
    public let isPreview: Bool
    public let action: (Action) async -> Void

    public init(
        _ appDependencies: AppDependencies,
        appName: String? = nil,
        systemInfoBundle: SystemInfoBundle = .cpuZero(),
        cpuRingBuffer: RingBuffer = .init(),
        memoryRingBuffer: RingBuffer = .init(),
        customMetricsBundles: [CustomMetricsBundle] = [],
        isPreview: Bool? = nil,
        action: @escaping (Action) async -> Void =  { _ in }
    ) {
        self.appStateClient = appDependencies.appStateClient
        self.nsAppClient = appDependencies.nsAppClient
        self.nsWorkspaceClient = appDependencies.nsWorkspaceClient
        self.userDefaultsRepository = .init(appDependencies.userDefaultsClient)
        self.logService = .init(appDependencies)
        self.appName = appName ?? appStateClient.withLock(\.name)
        self.systemInfoBundle = systemInfoBundle
        self.cpuRingBuffer = cpuRingBuffer
        self.memoryRingBuffer = memoryRingBuffer
        self.customMetricsBundles = customMetricsBundles
        self.isPreview = isPreview ?? ProcessInfo.isPreview
        self.action = action
    }

    public func reduce(_ action: Action) async {
        switch action {
        case let .task(screenName):
            logService.notice(.screenView(name: screenName))
            if let metrics = appStateClient.withLock(\.metrics.latestValue) {
                updateMetrics(metrics)
            }
            task?.cancel()
            task = Task { [weak self, appStateClient] in
                let stream = appStateClient.withLock(\.metrics.stream)
                for await value in stream {
                    self?.updateMetrics(value)
                }
            }

        case .onDisappear:
            task?.cancel()
            task = nil

        case .settingsButtonTapped:
            nsAppClient.activate(true)

        case .activityMonitorButtonTapped:
            guard let url = nsWorkspaceClient.urlForApplication(.activityMonitor) else { return }
            nsWorkspaceClient.openApplication(url, .init())

        case let .aboutButtonTapped(body):
            nsAppClient.activate(true)
            nsAppClient.orderFrontStandardAboutPanel([
                NSApplication.AboutPanelOptionKey.credits: NSAttributedString(body)
            ])

        case .reportIssueButtonTapped:
            guard let url = URL(string: .gitHubURL)?.appending(path: "issues") else { return }
            _ = nsWorkspaceClient.open(url)

        case .quitButtonTapped:
            nsAppClient.terminate(nil)

        case .debugSleepButtonTapped:
            nsWorkspaceClient.post(NSWorkspace.willSleepNotification, nil)

        case .debugWakeUpButtonTapped:
            nsWorkspaceClient.post(NSWorkspace.didWakeNotification, nil)
        }
    }

    private func updateMetrics(_ metrics: Metrics) {
        systemInfoBundle = metrics.systemInfoBundle
        cpuRingBuffer = metrics.cpuRingBuffer
        memoryRingBuffer = metrics.memoryRingBuffer
        customMetricsBundles = metrics.customMetricsBundles
    }

    public enum Action: Sendable {
        case task(String)
        case onDisappear
        case settingsButtonTapped
        case activityMonitorButtonTapped
        case aboutButtonTapped(AttributedString)
        case reportIssueButtonTapped
        case quitButtonTapped
        case debugSleepButtonTapped
        case debugWakeUpButtonTapped
    }
}
