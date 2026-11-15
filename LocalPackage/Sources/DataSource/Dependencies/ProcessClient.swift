/*
 ProcessClient.swift
 DataSource

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

public struct ProcessClient: DependencyClient {
    public var run: @Sendable (Process) throws -> Void
    public var readToEnd: @Sendable (FileHandle) throws -> Data?
    public var waitUntilExit: @Sendable (Process) -> Void
    public var terminationStatus: @Sendable (Process) -> Int32
    public var isRunning: @Sendable (Process) -> Bool
    public var terminate: @Sendable (Process) -> Void

    public static let liveValue = Self(
        run: { try $0.run() },
        readToEnd: { try $0.readToEnd() },
        waitUntilExit: { $0.waitUntilExit() },
        terminationStatus: { $0.terminationStatus },
        isRunning: { $0.isRunning },
        terminate: { $0.terminate() }
    )

    public static let testValue = Self(
        run: { _ in },
        readToEnd: { _ in nil },
        waitUntilExit: { _ in },
        terminationStatus: { _ in 0 },
        isRunning: { _ in false },
        terminate: { _ in }
    )
}
