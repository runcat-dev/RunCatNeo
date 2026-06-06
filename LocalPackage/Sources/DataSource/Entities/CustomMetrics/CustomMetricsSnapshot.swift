/*
 CustomMetricsSnapshot.swift
 DataSource

 Created by Takuto Nakamura on 2026/06/06.
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

public struct CustomMetricsSnapshot: Codable, Sendable, Equatable {
    public var title: String
    public var symbol: String?
    public var metrics: [CustomMetric]
    public var lastUpdatedDate: Date

    public init(
        title: String,
        symbol: String? = nil,
        metrics: [CustomMetric] = [],
        lastUpdatedDate: Date
    ) {
        self.title = title
        self.symbol = symbol
        self.metrics = metrics
        self.lastUpdatedDate = lastUpdatedDate
    }
}
