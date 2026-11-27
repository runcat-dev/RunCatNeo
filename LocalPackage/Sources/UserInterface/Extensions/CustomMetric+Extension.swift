/*
 CustomMetric+Extension.swift
 UserInterface

 Created by Takuto Nakamura on 2026/11/28.
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

extension CustomMetric {
    private static let lineGraphValueCountLimit = 60

    var barGraphValue: Double? {
        guard case let .value(value) = normalized else { return nil }
        return Self.graphPercentage(of: value)
    }

    var lineGraphValues: [Double]? {
        guard case let .values(values) = normalized else { return nil }
        let percentages = values.prefix(Self.lineGraphValueCountLimit).map(Self.graphPercentage(of:))
        return percentages.count < 2 ? [0, 0] : percentages
    }

    private static func graphPercentage(of normalizedValue: Double) -> Double {
        max(0, min(1, normalizedValue)) * 100
    }
}
