/*
 LogService.swift
 Model

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

import DataSource
import Foundation
import Logging

struct LogService {
    private let appStateClient: AppStateClient
    private let loggingSystemClient: LoggingSystemClient

    init(_ appDependencies: AppDependencies) {
        self.appStateClient = appDependencies.appStateClient
        self.loggingSystemClient = appDependencies.loggingSystemClient
    }

    func bootstrap() {
        guard !appStateClient.withLock(\.hasAlreadyBootstrap) else {
            return
        }
#if DEBUG
        loggingSystemClient.bootstrap { label in
            StreamLogHandler.standardOutput(label: label)
        }
#endif
        appStateClient.withLock { $0.hasAlreadyBootstrap = true }
    }

    nonisolated func notice(
        _ event: NoticeEvent,
        source: @autoclosure () -> String? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        Logger(label: Bundle.main.bundleIdentifier!).notice(
            event.message,
            metadata: event.metadata,
            source: source(),
            file: file,
            function: function,
            line: line
        )
    }

    nonisolated func error(
        _ event: ErrorEvent,
        source: @autoclosure () -> String? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        Logger(label: Bundle.main.bundleIdentifier!).error(
            event.message,
            metadata: event.metadata,
            source: source(),
            file: file,
            function: function,
            line: line
        )
    }

    nonisolated func critical(
        _ event: CriticalEvent,
        source: @autoclosure () -> String? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        Logger(label: Bundle.main.bundleIdentifier!).critical(
            event.message,
            metadata: event.metadata,
            source: source(),
            file: file,
            function: function,
            line: line
        )
    }
}
