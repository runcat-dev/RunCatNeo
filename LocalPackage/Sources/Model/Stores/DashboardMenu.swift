/*
 DashboardMenu.swift
 Model

 Created by Takuto Nakamura on 2026/09/28.
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
public final class DashboardMenu: Composable {
    private let appStateClient: AppStateClient
    private let nsAppClient: NSAppClient
    private let nsWorkspaceClient: NSWorkspaceClient
    private let logService: LogService
    private let runnerService: RunnerService

    @ObservationIgnored private var task: Task<Void, Never>?

    public var appName: String
    public var currentRunner: Runner?
    public var runnerBundleList: [RunnerBundle]
    public let isPreview: Bool
    public let action: (Action) async -> Void

    public init(
        _ appDependencies: AppDependencies,
        appName: String? = nil,
        currentRunner: Runner? = nil,
        runnerBundleList: [RunnerBundle] = [],
        isPreview: Bool? = nil,
        action: @escaping (Action) async -> Void = { _ in }
    ) {
        self.appStateClient = appDependencies.appStateClient
        self.nsAppClient = appDependencies.nsAppClient
        self.nsWorkspaceClient = appDependencies.nsWorkspaceClient
        self.logService = .init(appDependencies)
        self.runnerService = .init(appDependencies)
        self.appName = appName ?? appStateClient.withLock(\.name)
        self.currentRunner = currentRunner
        self.runnerBundleList = runnerBundleList
        self.isPreview = isPreview ?? ProcessInfo.isPreview
        self.action = action
    }

    public func reduce(_ action: Action) async {
        switch action {
        case .viewAppeared:
            if let runnerBundle = appStateClient.withLock(\.runnerBundles.latestValue) {
                currentRunner = runnerBundle.runner
            }
            runnerBundleList = appStateClient.withLock(\.runnerBundleLists.latestValue) ?? []
            task?.cancel()
            task = Task.immediate { [weak self, appStateClient] in
                await withTaskGroup { group in
                    group.addImmediateTask {
                        let stream = appStateClient.withLock(\.runnerBundles.stream)
                        for await value in stream {
                            self?.updateCurrentRunner(from: value)
                        }
                    }
                    group.addImmediateTask {
                        let stream = appStateClient.withLock(\.runnerBundleLists.stream)
                        for await value in stream {
                            self?.update(runnerBundleList: value)
                        }
                    }
                }
            }

        case .viewDisappeared:
            task?.cancel()
            task = nil

        case let .runnerKindPickerSelected(runner):
            guard let runner else { return }
            do {
                try runnerService.update(runner: runner)
                currentRunner = runner
            } catch {
                logService.error(.switchingRunnerFailed(error))
            }

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

        case let .openSourceLicenseButtonTapped(openWindow):
            nsAppClient.activate(true)
            openWindow(id: .openSourceLicense, value: Int.zero)

        case .reportIssueButtonTapped:
            _ = nsWorkspaceClient.open(URL.githubIssues)

        case .quitButtonTapped:
            nsAppClient.terminate(nil)

        case .debugSleepButtonTapped:
            nsWorkspaceClient.post(NSWorkspace.willSleepNotification, nil)

        case .debugWakeUpButtonTapped:
            nsWorkspaceClient.post(NSWorkspace.didWakeNotification, nil)
        }
    }

    private func updateCurrentRunner(from runnerBundle: RunnerBundle) {
        currentRunner = runnerBundle.runner
    }

    private func update(runnerBundleList: [RunnerBundle]) {
        self.runnerBundleList = runnerBundleList
    }

    public enum Action: Sendable {
        case viewAppeared
        case viewDisappeared
        case runnerKindPickerSelected(Runner?)
        case settingsButtonTapped
        case activityMonitorButtonTapped
        case aboutButtonTapped(AttributedString)
        case openSourceLicenseButtonTapped(OpenWindowActionWrapper)
        case reportIssueButtonTapped
        case quitButtonTapped
        case debugSleepButtonTapped
        case debugWakeUpButtonTapped
    }
}
