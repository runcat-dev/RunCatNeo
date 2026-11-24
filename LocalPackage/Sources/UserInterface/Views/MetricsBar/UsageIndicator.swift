/*
 UsageIndicator.swift
 UserInterface

 Created by Takuto Nakamura on 2026/11/23.
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

import CoreGraphics
import DataSource
import SystemInfoKit

enum UsageIndicator {
    case percentage(Percentage)
    case circularGauge(Percentage)
    case linearGauge(Percentage)
    case capacity(ByteData)

    var size: CGSize {
        switch self {
        case .percentage:
            IndicatorKind.usageFullLabel.size
        case .circularGauge:
            IndicatorKind.circularGauge.size
        case .linearGauge:
            IndicatorKind.linearGauge.size
        case let .capacity(byteData):
            IndicatorKind.capacityLabelSize(for: byteData.menuBarDescription(type: .storage))
        }
    }

    init(percentage: Percentage, style: MetricsBarUsageStyle) {
        self = switch style {
        case .percentage: .percentage(percentage)
        case .circularGauge: .circularGauge(percentage)
        case .linearGauge: .linearGauge(percentage)
        }
    }

    init(storageInfo: StorageInfo, style: MetricsBarStorageStyle) {
        self = switch style {
        case .percentage: .percentage(storageInfo.percentage)
        case .circularGauge: .circularGauge(storageInfo.percentage)
        case .linearGauge: .linearGauge(storageInfo.percentage)
        case .usedCapacity: .capacity(storageInfo.used)
        case .availableCapacity: .capacity(storageInfo.available)
        }
    }
}
