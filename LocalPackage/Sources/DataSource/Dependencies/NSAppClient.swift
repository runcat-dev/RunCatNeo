/*
 NSAppClient.swift
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

import AppKit

public struct NSAppClient: DependencyClient {
    public var activate: @MainActor @Sendable (Bool) -> Void
    public var terminate: @MainActor @Sendable (Any?) -> Void
    public var orderFrontStandardAboutPanel: @MainActor @Sendable ([NSApplication.AboutPanelOptionKey: Any]) -> Void

    public static let liveValue = Self(
        activate: { NSApp.activate(ignoringOtherApps: $0) },
        terminate: { NSApp.terminate($0) },
        orderFrontStandardAboutPanel: { NSApp.orderFrontStandardAboutPanel(options: $0) }
    )

    public static let testValue = Self(
        activate: { _ in },
        terminate: { _ in },
        orderFrontStandardAboutPanel: { _ in }
    )
}
