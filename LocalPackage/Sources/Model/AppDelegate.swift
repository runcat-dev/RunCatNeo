/*
 AppDelegate.swift
 Model

 Created by Takuto Nakamura on 2026/05/05.
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

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private let appDependencies = AppDependencies.shared

    public func applicationDidFinishLaunching(_ notification: Notification) {
        let appStateClient = appDependencies.appStateClient
        appStateClient.withLock {
            $0.name = Bundle.main.bundleDisplayName
            $0.version = Bundle.main.bundleVersion
        }
        let logService = LogService(appDependencies)
        logService.bootstrap()
        let nsWorkspaceClient = appDependencies.nsWorkspaceClient
        let customMetricsService = CustomMetricsService(appDependencies)
        let systemMetricsService = SystemMetricsService(appDependencies)
        let runnerService = RunnerService(appDependencies)
        Task {
            await withTaskGroup { group in
                group.addTask {
                    let publisher = nsWorkspaceClient.publisher(NSWorkspace.willSleepNotification)
                    for await _ in publisher.values {
                        customMetricsService.stopMonitoring()
                        systemMetricsService.stopMonitoring()
                    }
                }
                group.addTask {
                    let publisher = nsWorkspaceClient.publisher(NSWorkspace.didWakeNotification)
                    for await _ in publisher.values {
                        customMetricsService.startMonitoring()
                        systemMetricsService.startMonitoring()
                    }
                }
                group.addTask {
                    let stream = appStateClient.withLock(\.systemInfoObserver).systemInfoStream()
                    for await value in stream {
                        systemMetricsService.updateMetrics(from: value)
                        runnerService.updateRunnerSpeed(from: value.cpuInfo)
                    }
                }
            }
        }
        logService.notice(.launchApp)
        customMetricsService.startMonitoring()
        systemMetricsService.startMonitoring()
        do {
            try runnerService.setup()
        } catch {
            logService.critical(.setupFailed(error))
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        CustomMetricsService(appDependencies).stopMonitoring()
        SystemMetricsService(appDependencies).stopMonitoring()
    }
}
