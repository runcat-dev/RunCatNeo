/*
 CriticalEvent.swift
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

import Logging

public enum CriticalEvent {
    case setupFailed(any Error)
    case savingCustomRunnerFailed(any Error)
    case deletingCustomRunnerFailed(any Error)
    case unknown(any Error)

    public var message: Logger.Message {
        switch self {
        case .setupFailed:
            "Failed to setup."
        case .savingCustomRunnerFailed:
            "Failed saving custom runner."
        case .deletingCustomRunnerFailed:
            "Failed deleting custom runner."
        case .unknown:
            "An unknown error has occurred."
        }
    }

    public var metadata: Logger.Metadata? {
        switch self {
        case let .setupFailed(error),
            let .savingCustomRunnerFailed(error),
            let .deletingCustomRunnerFailed(error),
            let .unknown(error):
            ["cause": "\(error.localizedDescription)"]
        }
    }
}
