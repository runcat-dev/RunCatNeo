/*
 ArchivedRunner.swift
 DataSource

 Created by Takuto Nakamura on 2026/11/28.
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

public struct ArchivedRunner: Sendable {
    public static let maxFileSize = 16 * 1024 * 1024
    public static let maxEntryCount = 64
    public static let maxEntrySize = 512 * 1024
    public static let metadataEntryName = "metadata.json"

    public var runnerName: String
    public var isTemplate: Bool
    public var frameImages: [FrameImage]

    public init(runnerName: String, isTemplate: Bool, frameImages: [FrameImage]) {
        self.runnerName = runnerName
        self.isTemplate = isTemplate
        self.frameImages = frameImages
    }
}
