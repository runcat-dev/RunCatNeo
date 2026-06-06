/*
 URLClient.swift
 DataSource

 Created by Takuto Nakamura on 2026/06/06.
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

public struct URLClient: DependencyClient {
    public var create: @Sendable (Data, URL.BookmarkResolutionOptions) throws -> (Bool, URL)
    public var bookmarkData: @Sendable (URL, URL.BookmarkCreationOptions) throws -> Data
    public var startAccessingSecurityScopedResource: @Sendable (URL) -> Bool
    public var stopAccessingSecurityScopedResource: @Sendable (URL) -> Void

    public static let liveValue = Self(
        create: {
            var isStale = false
            let url = try URL(resolvingBookmarkData: $0, options: $1, bookmarkDataIsStale: &isStale)
            return (isStale, url)
        },
        bookmarkData: {
            try $0.bookmarkData(options: $1)
        },
        startAccessingSecurityScopedResource: {
            $0.startAccessingSecurityScopedResource()
        },
        stopAccessingSecurityScopedResource: {
            $0.stopAccessingSecurityScopedResource()
        }
    )

    public static let testValue = Self(
        create: { _, _ in throw URLError(.unknown) },
        bookmarkData: { _, _ in throw URLError(.unknown) },
        startAccessingSecurityScopedResource: { _ in false },
        stopAccessingSecurityScopedResource: { _ in }
    )
}
