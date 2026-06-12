/*
 UUIDClient.swift
 DataSource

 Created by Takuto Nakamura on 2026/05/05.
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

import Foundation

public struct UUIDClient: DependencyClient {
    public var create: @Sendable () -> UUID

    public static let liveValue = Self(
        create: { UUID() }
    )

    public static let testValue = Self(
        create: { UUID(0) }
    )
}

extension UUID {
    public init(_ intValue: Int) {
        self.init(uuidString: "00000000-0000-0000-0000-\(String(format: "%012x", intValue))")!
    }
}
