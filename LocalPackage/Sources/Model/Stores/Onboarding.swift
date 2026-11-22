/*
 Onboarding.swift
 Model

 Created by Takuto Nakamura on 2026/11/21.
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
import Observation

@MainActor @Observable
public final class Onboarding: Composable {
    private let nsAppClient: NSAppClient
    private let userDefaultsRepository: UserDefaultsRepository
    private let logService: LogService

    public let action: (Action) async -> Void

    public init(
        _ appDependencies: AppDependencies,
        action: @escaping (Action) async -> Void = { _ in }
    ) {
        self.nsAppClient = appDependencies.nsAppClient
        self.userDefaultsRepository = .init(appDependencies.userDefaultsClient)
        self.logService = .init(appDependencies)
        self.action = action
    }

    public func reduce(_ action: Action) async {
        switch action {
        case let .viewAppeared(screenName):
            logService.notice(.screenView(name: screenName))
            userDefaultsRepository.hasShownOnboarding = true
            nsAppClient.activate(true)

        case let .okButtonTapped(dismissWindow):
            dismissWindow(id: .onboarding)
        }
    }

    public enum Action: Sendable {
        case viewAppeared(String)
        case okButtonTapped(DismissWindowActionWrapper)
    }
}
