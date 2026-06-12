/*
 FrameOrder.swift
 DataSource

 Created by Takuto Nakamura on 2026/05/09.
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

public enum FrameOrder: Sendable {
    case ascending(Int)
    case swing
    case pendulum
    case partyHorn
    case custom([Int])

    var order: [Int] {
        switch self {
        case let .ascending(n):
            Array(.zero ..< n)
        case .swing:
            [0, 1, 2, 3, 4, 3, 2, 1]
        case .pendulum:
            [0, 1, 2, 1, 0, 3, 4, 3]
        case .partyHorn:
            [0, 1, 2, 3, 4, 4, 3, 2, 1]
        case let .custom(order):
            order
        }
    }

    public subscript(index: Int) -> Int {
        let o = order
        return if index < o.count {
            o[index]
        } else {
            .zero
        }
    }
}

extension FrameOrder: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let order = try container.decode([Int].self)
        self = .custom(order)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(order)
    }
}
