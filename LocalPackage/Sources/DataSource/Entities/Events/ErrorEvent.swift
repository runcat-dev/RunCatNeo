/*
 ErrorEvent.swift
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

import Logging

public enum ErrorEvent {
    case donationFailed(any Error)
    case importingCustomMetricsSourceFailed(any Error)
    case importingFrameImagesFailed(any Error)

    public var message: Logger.Message {
        switch self {
        case .donationFailed:
            "Donation failed."
        case .importingCustomMetricsSourceFailed:
            "Failed importing custom metrics source."
        case .importingFrameImagesFailed:
            "Failed importing frame images."
        }
    }

    public var metadata: Logger.Metadata? {
        switch self {
        case let .donationFailed(error),
            let .importingCustomMetricsSourceFailed(error),
            let .importingFrameImagesFailed(error):
            ["cause": "\(error.localizedDescription)"]
        }
    }
}
