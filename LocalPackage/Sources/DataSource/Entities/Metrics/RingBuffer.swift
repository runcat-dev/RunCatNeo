/*
 RingBuffer.swift
 DataSource

 Created by Takuto Nakamura on 2026/05/21.
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

public struct RingBuffer: Sendable {
    private let length: Int
    public private(set) var values: [Double]

    public init(length: Int = 61) {
        self.length = length
        values = [Double](repeating: 2, count: length)
    }

    public mutating func append(_ value: Double) {
        values.append(value)
        values.removeFirst()
    }

    public mutating func append(_ values: [Double]) {
        self.values.append(contentsOf: values)
        self.values = self.values.suffix(length)
    }
}
