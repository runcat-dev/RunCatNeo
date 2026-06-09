/*
 Runner.swift
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

import Foundation

public struct Runner: Sendable, Hashable, Identifiable {
    public var id: String
    public var isTemplate: Bool
    public var frameOrder: FrameOrder
    public var source: RunnerSource

    public var isCustom: Bool {
        if case .custom = source { true } else { false }
    }

    public init(id: String, name: String, isTemplate: Bool, frameOrder: FrameOrder) {
        self.id = id
        self.isTemplate = isTemplate
        self.frameOrder = frameOrder
        self.source = .custom(name: name)
    }

    public init(kind: RunnerKind) {
        id = kind.id
        isTemplate = true
        frameOrder = kind.frameOrder
        source = .builtIn(kind)
    }

    public func resourceNames() -> [String] {
        frameOrder.order.map { frameNumber in
            if isCustom {
                "frame-\(frameNumber)"
            } else {
                "\(id)-frame-\(frameNumber)"
            }
        }
    }

    public static let `default` = Runner(kind: .cat)

    public static func ==(lhs: Runner, rhs: Runner) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension Runner: Codable {
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case isTemplate
        case frameOrder
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        isTemplate = try container.decode(Bool.self, forKey: .isTemplate)
        frameOrder = try container.decode(FrameOrder.self, forKey: .frameOrder)
        let name = try container.decode(String.self, forKey: .name)
        source = .custom(name: name)
    }

    public func encode(to encoder: any Encoder) throws {
        guard case let .custom(name) = source else {
            throw EncodingError.invalidValue(source, EncodingError.Context(
                codingPath: encoder.codingPath,
                debugDescription: "Only custom runners are persisted."
            ))
        }
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(isTemplate, forKey: .isTemplate)
        try container.encode(frameOrder, forKey: .frameOrder)
    }
}
