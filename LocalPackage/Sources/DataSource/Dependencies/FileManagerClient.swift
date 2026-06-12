/*
 FileManagerClient.swift
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

public struct FileManagerClient: DependencyClient {
    public var urls: @Sendable (FileManager.SearchPathDirectory, FileManager.SearchPathDomainMask) -> [URL]
    public var fileExists: @Sendable (String) -> Bool
    public var createDirectory: @Sendable (URL, Bool) throws -> Void
    public var removeItem: @Sendable (URL) throws -> Void

    public static let liveValue = Self(
        urls: { FileManager.default.urls(for: $0, in: $1) },
        fileExists: { FileManager.default.fileExists(atPath: $0) },
        createDirectory: { try FileManager.default.createDirectory(at: $0, withIntermediateDirectories: $1) },
        removeItem: { try FileManager.default.removeItem(at: $0) }
    )

    public static let testValue = Self(
        urls: { _, _ in [URL(filePath: "/Users/user/Library/Application Support/")] },
        fileExists: { _ in false },
        createDirectory: { _, _ in },
        removeItem: { _ in }
    )
}
