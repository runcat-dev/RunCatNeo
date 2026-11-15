/*
 SystemPowerReportRepository.swift
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

public struct SystemPowerReportRepository: Sendable {
    private let processClient: ProcessClient

    public init(_ processClient: ProcessClient) {
        self.processClient = processClient
    }

    public func read() -> Data? {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/sbin/system_profiler")
        process.arguments = ["SPPowerDataType", "-json", "-detailLevel", "mini", "-timeout", "10"]
        process.qualityOfService = .utility
        var environment = ProcessInfo.processInfo.environment
        environment["LC_ALL"] = "C"
        process.environment = environment
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        defer {
            if processClient.isRunning(process) {
                processClient.terminate(process)
            }
        }
        do {
            try processClient.run(process)
            let data = try processClient.readToEnd(output.fileHandleForReading)
            processClient.waitUntilExit(process)
            guard processClient.terminationStatus(process) == 0 else { return nil }
            return data
        } catch {
            return nil
        }
    }
}
