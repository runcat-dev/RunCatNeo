/*
 RunnerKind+Extension.swift
 UserInterface

 Created by Takuto Nakamura on 2026/06/10.
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

extension RunnerKind {
    var localizedName: String {
        switch self {
        case .cat:
            String(localized: "cat", table: "RunnerNames", bundle: .module)
        case .parrot:
            String(localized: "parrot", table: "RunnerNames", bundle: .module)
        case .slime:
            String(localized: "slime", table: "RunnerNames", bundle: .module)
        case .greyhound:
            String(localized: "greyhound", table: "RunnerNames", bundle: .module)
        case .welshCorgi:
            String(localized: "welshCorgi", table: "RunnerNames", bundle: .module)
        case .drop:
            String(localized: "drop", table: "RunnerNames", bundle: .module)
        case .coffee:
            String(localized: "coffee", table: "RunnerNames", bundle: .module)
        case .newtonCradle:
            String(localized: "newtonCradle", table: "RunnerNames", bundle: .module)
        case .engine:
            String(localized: "engine", table: "RunnerNames", bundle: .module)
        case .mochi:
            String(localized: "mochi", table: "RunnerNames", bundle: .module)
        }
    }
}
