/*
 AppState.swift
 DataSource

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

import Foundation
import SystemInfoKit

public struct AppState: Sendable {
    public var name: String
    public var version: String
    public var hasAlreadyBootstrap: Bool
    public let monitorInterval: Int
    public var metrics = AsyncStreamBundle<Metrics>()
    public let systemInfoObserver = SystemInfoObserver.shared
    public var systemMetricsConfigurationChanges = AsyncStreamBundle<Void>()
    public var customMetricsReconcileObserver: Task<Void, Never>?
    public var customMetricsObservers = [UUID: Task<Void, Never>]()
    public var customMetricsConfigurationChanges = AsyncStreamBundle<Void>()
    public var runnerBundleLists = AsyncStreamBundle<[RunnerBundle]>()
    public var runnerBundles = AsyncStreamBundle<RunnerBundle>()
    public var runnerSpeeds = AsyncStreamBundle<Float>()

    init(
        name: String = "",
        version: String = "",
        hasAlreadyBootstrap: Bool = false,
        monitorInterval: Int = 5
    ) {
        self.name = name
        self.version = version
        self.hasAlreadyBootstrap = hasAlreadyBootstrap
        self.monitorInterval = monitorInterval
    }
}
