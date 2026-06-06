/*
 AppDependencies.swift
 Model

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

import DataSource
import SwiftUI

public struct AppDependencies: Sendable {
    public var appStateClient = AppStateClient.liveValue
    public var dataClient = DataClient.liveValue
    public var dateClient = DateClient.liveValue
    public var fileManagerClient = FileManagerClient.liveValue
    public var fileWatcherClient = FileWatcherClient.liveValue
    public var loggingSystemClient = LoggingSystemClient.liveValue
    public var nsAppClient = NSAppClient.liveValue
    public var nsWorkspaceClient = NSWorkspaceClient.liveValue
    public var smAppServiceClient = SMAppServiceClient.liveValue
    public var urlClient = URLClient.liveValue
    public var userDefaultsClient = UserDefaultsClient.liveValue
    public var uuidClient = UUIDClient.liveValue

    static let shared = AppDependencies()
}

extension EnvironmentValues {
    @Entry public var appDependencies = AppDependencies.shared
}

extension AppDependencies {
    public static func testDependencies(
        appStateClient: AppStateClient = .testValue,
        dataClient: DataClient = .testValue,
        dateClient: DateClient = .testValue,
        fileManagerClient: FileManagerClient = .testValue,
        fileWatcherClient: FileWatcherClient = .testValue,
        loggingSystemClient: LoggingSystemClient = .testValue,
        nsAppClient: NSAppClient = .testValue,
        nsWorkspaceClient: NSWorkspaceClient = .testValue,
        smAppServiceClient: SMAppServiceClient = .testValue,
        urlClient: URLClient = .testValue,
        userDefaultsClient: UserDefaultsClient = .testValue,
        uuidClient: UUIDClient = .testValue
    ) -> AppDependencies {
        AppDependencies(
            appStateClient: appStateClient,
            dataClient: dataClient,
            dateClient: dateClient,
            fileManagerClient: fileManagerClient,
            fileWatcherClient: fileWatcherClient,
            loggingSystemClient: loggingSystemClient,
            nsAppClient: nsAppClient,
            nsWorkspaceClient: nsWorkspaceClient,
            smAppServiceClient: smAppServiceClient,
            urlClient: urlClient,
            userDefaultsClient: userDefaultsClient,
            uuidClient: uuidClient
        )
    }
}
