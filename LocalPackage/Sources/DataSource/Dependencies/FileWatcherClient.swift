/*
 FileWatcherClient.swift
 DataSource

 Created by Takuto Nakamura on 2026/06/06.
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

import Darwin
import Dispatch
import Foundation

public struct FileWatcherClient: DependencyClient {
    public var watch: @Sendable (URL) -> AsyncStream<Date>

    public static let liveValue = Self(
        watch: { url in
            AsyncStream<Date>(bufferingPolicy: .bufferingNewest(1)) { continuation in
                let descriptor = open(url.path, O_EVTONLY)
                guard descriptor >= 0 else {
                    continuation.finish()
                    return
                }
                let source = DispatchSource.makeFileSystemObjectSource(
                    fileDescriptor: descriptor,
                    eventMask: [.write, .rename, .delete, .extend],
                    queue: DispatchQueue.global(qos: .utility)
                )
                source.setEventHandler {
                    let data = source.data
                    continuation.yield(Date())
                    if data.contains(.rename) || data.contains(.delete) {
                        continuation.finish()
                    }
                }
                source.setCancelHandler {
                    close(descriptor)
                }
                source.resume()
                continuation.onTermination = { _ in
                    source.cancel()
                }
                continuation.yield(Date())
            }
        }
    )

    public static let testValue = Self(
        watch: { _ in AsyncStream { _ in } }
    )
}
