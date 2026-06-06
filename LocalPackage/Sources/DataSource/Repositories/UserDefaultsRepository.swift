/*
 UserDefaultsRepository.swift
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

public struct UserDefaultsRepository: Sendable {
    private var userDefaultsClient: UserDefaultsClient

    public var runnerID: Runner.ID {
        get { userDefaultsClient.string(.runnerID) ?? RunnerKind.cat.id }
        nonmutating set { userDefaultsClient.set(newValue, .runnerID) }
    }

    public var speedDecreasesUnderLoad: Bool {
        get { userDefaultsClient.bool(.speedDecreasesUnderLoad) }
        nonmutating set { userDefaultsClient.set(newValue, .speedDecreasesUnderLoad) }
    }

    public var isFlippedHorizontally: Bool {
        get { userDefaultsClient.bool(.isFlippedHorizontally) }
        nonmutating set { userDefaultsClient.set(newValue, .isFlippedHorizontally) }
    }

    public var systemMetricsConfiguration: SystemMetricsConfiguration {
        get {
            guard let data = userDefaultsClient.data(.systemMetricsConfiguration),
                  let value = try? JSONDecoder().decode(SystemMetricsConfiguration.self, from: data) else {
                return .default
            }
            return value
        }
        nonmutating set {
            if let data = try? JSONEncoder().encode(newValue) {
                userDefaultsClient.set(data, .systemMetricsConfiguration)
            } else {
                userDefaultsClient.removeObject(.systemMetricsConfiguration)
            }
        }
    }

    public var showsMetricsBar: Bool {
        get { userDefaultsClient.bool(.showsMetricsBar) }
        nonmutating set { userDefaultsClient.set(newValue, .showsMetricsBar) }
    }

    public var metricsBarConfiguration: MetricsBarConfiguration {
        get {
            guard let data = userDefaultsClient.data(.metricsBarConfiguration),
                  let value = try? JSONDecoder().decode(MetricsBarConfiguration.self, from: data) else {
                return .default
            }
            return value
        }
        nonmutating set {
            if let data = try? JSONEncoder().encode(newValue) {
                userDefaultsClient.set(data, .metricsBarConfiguration)
            } else {
                userDefaultsClient.removeObject(.metricsBarConfiguration)
            }
        }
    }

    public var customMetricsConfiguration: CustomMetricsConfiguration {
        get {
            guard let data = userDefaultsClient.data(.customMetricsConfiguration),
                  let value = try? JSONDecoder().decode(CustomMetricsConfiguration.self, from: data) else {
                return .empty
            }
            return value
        }
        nonmutating set {
            if let data = try? JSONEncoder().encode(newValue) {
                userDefaultsClient.set(data, .customMetricsConfiguration)
            } else {
                userDefaultsClient.removeObject(.customMetricsConfiguration)
            }
        }
    }

    public init(_ userDefaultsClient: UserDefaultsClient) {
        self.userDefaultsClient = userDefaultsClient
        if ProcessInfo.needsResetUserDefaults {
            userDefaultsClient.removePersistentDomain(Bundle.main.bundleIdentifier!)
        }
        userDefaultsClient.register([
            .runnerID: RunnerKind.cat.id,
            .speedDecreasesUnderLoad: false,
            .isFlippedHorizontally: false,
        ])
        if ProcessInfo.needsShowAllData {
            showAllData()
        }
    }

    private func showAllData() {
        guard let dict = userDefaultsClient.persistentDomain(Bundle.main.bundleIdentifier!) else {
            return
        }
        for (key, value) in dict.sorted(by: { $0.0 < $1.0 }) {
            Swift.print("\(key) => \(value)")
        }
    }
}
