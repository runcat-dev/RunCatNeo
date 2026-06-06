/*
 NSWorkspaceClient.swift
 DataSource

 Created by Takuto Nakamura on 2026/05/05.
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

import AppKit
import Combine

public struct NSWorkspaceClient: DependencyClient {
    public var open: @Sendable (URL) -> Bool
    public var urlForApplication: @Sendable (String) -> URL?
    public var openApplication: @Sendable (URL, NSWorkspace.OpenConfiguration) -> Void
    public var activateFileViewerSelecting: @Sendable ([URL]) -> Void
    public var post: @Sendable (Notification.Name, Any?) -> Void
    public var publisher: @Sendable (Notification.Name) -> AnyPublisher<Notification, Never>

    public static let liveValue = Self(
        open: { NSWorkspace.shared.open($0) },
        urlForApplication: { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) },
        openApplication: { NSWorkspace.shared.openApplication(at: $0, configuration: $1) },
        activateFileViewerSelecting: { NSWorkspace.shared.activateFileViewerSelecting($0) },
        post: { NSWorkspace.shared.notificationCenter.post(name: $0, object: $1) },
        publisher: { NSWorkspace.shared.notificationCenter.publisher(for: $0).eraseToAnyPublisher() }
    )

    public static let testValue = Self(
        open: { _ in false },
        urlForApplication: { _ in nil },
        openApplication: { _, _ in },
        activateFileViewerSelecting: { _ in },
        post: { _, _ in },
        publisher: { _ in Empty<Notification, Never>().eraseToAnyPublisher() }
    )
}
