/*
 SystemMetricsService.swift
 Model

 Created by Takuto Nakamura on 2026/05/07.
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
import SystemInfoKit

struct SystemMetricsService {
    private let appStateClient: AppStateClient
    private let userDefaultsRepository: UserDefaultsRepository

    var currentSystemInfoBundle: SystemInfoBundle {
        appStateClient.withLock(\.systemInfoObserver.currentSystemInfo)
    }

    init(_ appDependencies: AppDependencies) {
        self.appStateClient = appDependencies.appStateClient
        self.userDefaultsRepository = .init(appDependencies.userDefaultsClient)
    }

    func stopMonitoring() {
        appStateClient.withLock {
            $0.systemInfoObserver.stopMonitoring()
        }
    }

    func startMonitoring() {
        let configuration = userDefaultsRepository.systemMetricsConfiguration
        appStateClient.withLock {
            $0.systemInfoObserver.toggleActivation(requests: [
                SystemInfoType.cpu: true,
                SystemInfoType.memory: configuration.monitorsMemory,
                SystemInfoType.storage: configuration.monitorsStorage,
                SystemInfoType.battery: configuration.monitorsBattery,
                SystemInfoType.network: configuration.monitorsNetwork,
            ])
            $0.systemInfoObserver.startMonitoring(monitorInterval: Double($0.monitorInterval))
        }
    }

    func toggleSystemInfoActivation(type: SystemInfoType, isOn: Bool) {
        appStateClient.withLock {
            $0.systemInfoObserver.toggleActivation(requests: [type: isOn])
        }
    }

    func updateMetrics(from systemInfoBundle: SystemInfoBundle) {
        appStateClient.withLock {
            var metrics = $0.metrics.latestValue ?? .init()
            metrics.systemInfoBundle = systemInfoBundle
            if let value = systemInfoBundle.cpuInfo?.percentage.value {
                metrics.cpuRingBuffer.append(value)
            }
            if let value = systemInfoBundle.memoryInfo?.percentage.value {
                metrics.memoryRingBuffer.append(value)
            }
            $0.metrics.send(metrics)
        }
    }

    func emitConfigurationChange() {
        appStateClient.withLock {
            $0.systemMetricsConfigurationChanges.send()
        }
    }
}
