/*
 SystemInfoObserverClient.swift
 DataSource

 Created by Takuto Nakamura on 2026/06/07.
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

import SystemInfoKit

public struct SystemInfoObserverClient: DependencyClient {
    public var systemInfoStream: @Sendable () -> AsyncStream<SystemInfoBundle>
    public var currentSystemInfo: @Sendable () -> SystemInfoBundle
    public var startMonitoring: @Sendable (Double) -> Void
    public var stopMonitoring: @Sendable () -> Void
    public var toggleActivation: @Sendable ([SystemInfoType: Bool]) -> Void

    public static let liveValue = Self(
        systemInfoStream: { SystemInfoObserver.shared.systemInfoStream() },
        currentSystemInfo: { SystemInfoObserver.shared.currentSystemInfo },
        startMonitoring: { SystemInfoObserver.shared.startMonitoring(monitorInterval: $0) },
        stopMonitoring: { SystemInfoObserver.shared.stopMonitoring() },
        toggleActivation: { SystemInfoObserver.shared.toggleActivation(requests: $0) }
    )

    public static let testValue = Self(
        systemInfoStream: { AsyncStream { $0.finish() } },
        currentSystemInfo: { SystemInfoBundle() },
        startMonitoring: { _ in },
        stopMonitoring: {},
        toggleActivation: { _ in }
    )
}
