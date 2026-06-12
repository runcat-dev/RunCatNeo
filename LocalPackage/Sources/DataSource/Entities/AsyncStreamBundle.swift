/*
 AsyncStreamBundle.swift
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

import AsyncAlgorithms

public typealias AsyncShareStream<T: Sendable> = Sendable & AsyncSequence<T, AsyncStream<T>.__AsyncSequence_Failure>

public struct AsyncStreamBundle<T>: Sendable where T: Sendable {
    public let stream: any AsyncShareStream<T>
    private let continuation: AsyncStream<T>.Continuation
    public private(set) var latestValue: T? = nil

    public init() {
        let (stream, continuation) = AsyncStream.makeStream(
            of: T.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        self.stream = stream.share(bufferingPolicy: .bufferingLatest(1))
        self.continuation = continuation
    }

    public mutating func send(_ value: T) {
        latestValue = value
        continuation.yield(value)
    }
}

extension AsyncStreamBundle where T == Void {
    public mutating func send() {
        send(())
    }
}
