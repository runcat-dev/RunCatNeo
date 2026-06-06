/*
 RCNError+Extension.swift
 UserInterface

 Created by Takuto Nakamura on 2026/05/31.
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
import Foundation
import SwiftUI

extension RCNError.CustomRunner: LocalizedError {
    public var errorDescription: String? {
        let localizationValue: String.LocalizationValue = switch self {
        case .runnerInUse:
            "runnerInUse"
        case .nameAlreadyExists:
            "nameAlreadyExists"
        case .invalidFrameImage:
            "invalidFrameImage"
        case .frameLimitExceeded:
            "frameLimitExceeded"
        case .savingFailed:
            "savingFailed"
        case .loadingFailed:
            "loadingFailed"
        }
        return String(localized: localizationValue, bundle: .module)
    }
}

extension RCNError.CustomMetrics: LocalizedError {
    public var errorDescription: String? {
        let localizationValue: String.LocalizationValue = switch self {
        case .fileUnreadable:
            "fileUnreadable"
        }
        return String(localized: localizationValue, bundle: .module)
    }
}

extension RCNError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .customRunner(detail):
            detail.errorDescription
        case let .customMetrics(detail):
            detail.errorDescription
        }
    }
}
