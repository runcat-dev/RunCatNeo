/*
 BatteryStatusInfo.swift
 DataSource

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

public struct BatteryStatusInfo: SystemInfo {
    private let battery: BatteryInfo
    private let maximumCapacityPercent: Double?

    public init(battery: BatteryInfo, maximumCapacityPercent: Double?) {
        self.battery = battery
        self.maximumCapacityPercent = maximumCapacityPercent.flatMap {
            $0.isFinite && (0...100).contains($0) ? $0 : nil
        }
    }

    public var type: SystemInfoType { battery.type }
    public var icon: String { battery.icon }
    public var percentage: Percentage { battery.percentage }
    public var summary: String { battery.summary }

    public var details: [String] {
        var details = battery.details
        guard details.indices.contains(1) else { return details }
        let value = maximumCapacityPercent.map {
            String(describing: Percentage(rawValue: $0 / 100, width: 5))
        } ?? "—"
        details[1] = details[1].replacingOccurrences(
            of: String(describing: battery.maxCapacity),
            with: value
        )
        return details
    }

    public var description: String {
        battery.isInstalled ? ([summary] + details).joined(separator: "\n\t") : summary
    }
}
