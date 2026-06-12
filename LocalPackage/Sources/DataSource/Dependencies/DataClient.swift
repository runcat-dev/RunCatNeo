/*
 DataClient.swift
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

import ImageIO
import UniformTypeIdentifiers

public struct DataClient: DependencyClient {
    public var read: @Sendable (URL) throws -> Data
    public var write: @Sendable (Data, URL) throws -> Void
    public var convert: @Sendable (CGImage, UTType) throws -> Data

    public static let liveValue = Self(
        read: { try Data(contentsOf: $0) },
        write: { try $0.write(to: $1) },
        convert: {
            let data = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(data, $1.identifier as CFString, 1, nil) else {
                throw CGError.failure.nsError
            }
            CGImageDestinationAddImage(destination, $0, nil)
            guard CGImageDestinationFinalize(destination) else {
                throw CGError.failure.nsError
            }
            return data as Data
        }
    )

    public static let testValue = Self(
        read: { _ in Data() },
        write: { _, _ in },
        convert: { _, _ in Data() }
    )
}
