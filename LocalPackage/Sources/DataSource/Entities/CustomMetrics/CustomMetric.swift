/*
 CustomMetric.swift
 DataSource

 Created by Takuto Nakamura on 2026/06/06.
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

public struct CustomMetric: Decodable, Sendable, Equatable {
    public var title: String
    public var formattedValue: String
    public var normalized: Normalized?

    public enum Normalized: Sendable, Equatable {
        case value(Double)
        case values([Double])
    }

    private enum CodingKeys: String, CodingKey {
        case title
        case formattedValue
        case normalizedValue
        case normalizedValues
    }

    public init(title: String, formattedValue: String, normalized: Normalized? = nil) {
        self.title = title
        self.formattedValue = formattedValue
        self.normalized = normalized
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        formattedValue = try container.decode(String.self, forKey: .formattedValue)
        let normalizedValue = try container.decodeIfPresent(Double.self, forKey: .normalizedValue)
        let normalizedValues = try container.decodeIfPresent([Double].self, forKey: .normalizedValues)
        switch (normalizedValue, normalizedValues) {
        case let (value?, nil):
            normalized = .value(value)
        case let (nil, values?):
            normalized = .values(values)
        case (nil, nil):
            normalized = nil
        case (.some, .some):
            throw DecodingError.dataCorruptedError(
                forKey: .normalizedValues,
                in: container,
                debugDescription: "normalizedValue and normalizedValues are mutually exclusive."
            )
        }
    }
}
