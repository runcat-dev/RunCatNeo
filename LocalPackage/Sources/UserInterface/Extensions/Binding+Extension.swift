/*
 Binding+Extension.swift
 UserInterface

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

import SwiftUI

extension Binding where Value : Sendable {
    @preconcurrency init(
        @_inheritActorContext get: @escaping @isolated(any) @Sendable () -> Value,
        @_inheritActorContext asyncSet: @escaping @isolated(any) @Sendable (Value) async -> Void
    ) {
        self.init(get: get, set: { newValue in Task { await asyncSet(newValue) } })
    }
}
