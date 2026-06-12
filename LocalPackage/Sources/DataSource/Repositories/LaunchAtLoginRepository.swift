/*
 LaunchAtLoginRepository.swift
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

import Foundation

public struct LaunchAtLoginRepository: Sendable {
    private var smAppServiceClient: SMAppServiceClient

    public var isEnabled: Bool {
        smAppServiceClient.status() == .enabled
    }

    public init(_ smAppServiceClient: SMAppServiceClient) {
        self.smAppServiceClient = smAppServiceClient
    }

    public func switchStatus(_ isEnabled: Bool) -> Result<Void, OperationError> {
        let switchSucceeded: Bool = {
            do {
                if isEnabled {
                    try smAppServiceClient.register()
                } else {
                    try smAppServiceClient.unregister()
                }
                return true
            } catch {
                return false
            }
        }()
        let value = self.isEnabled
        return if switchSucceeded, value == isEnabled {
            .success(())
        } else {
            .failure(.switchFailed(value))
        }
    }

    public enum OperationError: Error, Equatable {
        case switchFailed(Bool)
    }
}
