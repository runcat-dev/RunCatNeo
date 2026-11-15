/*
 BatteryHealthReport.swift
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

public enum BatteryHealthReport {
    public static func maximumCapacityPercent(from data: Data) -> Double? {
        guard let report = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = report["SPPowerDataType"] as? [[String: Any]] else {
            return nil
        }
        for entry in entries {
            guard let health = entry["sppower_battery_health_info"] as? [String: Any],
                  let text = health["sppower_battery_health_maximum_capacity"] as? String else {
                continue
            }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasSuffix("%"),
                  let value = Double(trimmed.dropLast().trimmingCharacters(in: .whitespaces)),
                  value.isFinite, (0...100).contains(value) else {
                continue
            }
            return value
        }
        return nil
    }
}
