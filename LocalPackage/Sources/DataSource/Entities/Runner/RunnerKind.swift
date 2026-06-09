/*
 RunnerKind.swift
 DataSource

 Created by Takuto Nakamura on 2026/05/09.
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

public enum RunnerKind: String, Sendable, Identifiable, CaseIterable {
    case cat = "cat"
    case parrot = "parrot"
    case slime = "slime"
    case greyhound = "greyhound"
    case welshCorgi = "welsh-corgi"
    case drop = "drop"
    case coffee = "coffee"
    case newtonCradle = "newton-cradle"
    case engine = "engine"
    case mochi = "mochi"

    public var id: String { rawValue }

    var numberOfResources: Int {
        switch self {
        case .cat: 5
        case .parrot: 5
        case .slime: 5
        case .greyhound: 14
        case .welshCorgi: 7
        case .drop: 5
        case .coffee: 10
        case .newtonCradle: 5
        case .engine: 10
        case .mochi: 5
        }
    }

    var frameOrder: FrameOrder {
        let n = numberOfResources
        return switch self {
        case .cat: .ascending(n)
        case .parrot: .ascending(n)
        case .slime: .partyHorn
        case .greyhound: .ascending(n)
        case .welshCorgi: .ascending(n)
        case .drop: .ascending(n)
        case .coffee: .ascending(n)
        case .newtonCradle: .pendulum
        case .engine: .ascending(n)
        case .mochi: .swing
        }
    }
}
