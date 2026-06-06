/*
 CustomMetricsSource.swift
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

public struct CustomMetricsSource: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var displayName: String
    public var fileURL: URL
    public var bookmark: Data
    public var createdAt: Date

    public init(
        id: UUID,
        displayName: String,
        fileURL: URL,
        bookmark: Data,
        createdAt: Date
    ) {
        self.id = id
        self.displayName = displayName
        self.fileURL = fileURL
        self.bookmark = bookmark
        self.createdAt = createdAt
    }
}
