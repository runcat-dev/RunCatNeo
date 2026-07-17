/*
 MetricsBarConfiguration.swift
 DataSource

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

import Foundation

public struct MetricsBarConfiguration: Codable, Sendable, Equatable {
    public var showsCPU: Bool
    public var showsMemory: Bool
    public var showsStorage: Bool
    public var showsBattery: Bool
    public var showsNetwork: Bool
    public var visibleCustomMetricsSourceIDs: Set<UUID>
    public var storageDisplayFormat: StorageDisplayFormat

    public var isEmpty: Bool {
        !showsCPU && !showsMemory && !showsStorage && !showsBattery && !showsNetwork
            && visibleCustomMetricsSourceIDs.isEmpty
    }

    public func showsCustomMetrics(of id: UUID) -> Bool {
        visibleCustomMetricsSourceIDs.contains(id)
    }

    public init(
        showsCPU: Bool,
        showsMemory: Bool,
        showsStorage: Bool,
        showsBattery: Bool,
        showsNetwork: Bool,
        visibleCustomMetricsSourceIDs: Set<UUID>,
        storageDisplayFormat: StorageDisplayFormat = .default
    ) {
        self.showsCPU = showsCPU
        self.showsMemory = showsMemory
        self.showsStorage = showsStorage
        self.showsBattery = showsBattery
        self.showsNetwork = showsNetwork
        self.visibleCustomMetricsSourceIDs = visibleCustomMetricsSourceIDs
        self.storageDisplayFormat = storageDisplayFormat
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        showsCPU = try container.decode(Bool.self, forKey: .showsCPU)
        showsMemory = try container.decode(Bool.self, forKey: .showsMemory)
        showsStorage = try container.decode(Bool.self, forKey: .showsStorage)
        showsBattery = try container.decode(Bool.self, forKey: .showsBattery)
        showsNetwork = try container.decode(Bool.self, forKey: .showsNetwork)
        visibleCustomMetricsSourceIDs = try container.decode(Set<UUID>.self, forKey: .visibleCustomMetricsSourceIDs)
        storageDisplayFormat = try container.decodeIfPresent(
            StorageDisplayFormat.self,
            forKey: .storageDisplayFormat
        ) ?? .default
    }

    public static let `default` = Self(
        showsCPU: true,
        showsMemory: false,
        showsStorage: false,
        showsBattery: false,
        showsNetwork: false,
        visibleCustomMetricsSourceIDs: [],
        storageDisplayFormat: .default
    )
}
