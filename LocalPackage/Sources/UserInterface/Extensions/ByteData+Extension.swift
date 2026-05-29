/*
 ByteData+Extension.swift
 UserInterface

 Created by Takuto Nakamura on 2026/05/25.
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

import SystemInfoKit

extension ByteData {
    func menuBarDescription(type: SystemInfoType) -> String {
        let (value, unit) = readableValue
        return switch type {
        case .storage:
            String(format: "%5.2f %@", locale: .current, value, unit)
        case .network:
            String(format: value < 100 ? "%4.1f %@/s" : "%4.0f %@/s", locale: .current, value, unit)
        default:
            description
        }
    }
}
