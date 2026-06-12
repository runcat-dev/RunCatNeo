/*
 UserDefaultsClient.swift
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

public struct UserDefaultsClient: DependencyClient {
    var bool: @Sendable (String) -> Bool
    var integer: @Sendable (String) -> Int
    var string: @Sendable (String) -> String?
    var data: @Sendable (String) -> Data?
    var set: @Sendable (Any?, String) -> Void
    var removeObject: @Sendable (String) -> Void
    var register: @Sendable ([String: Any]) -> Void
    var removePersistentDomain: @Sendable (String) -> Void
    var persistentDomain: @Sendable (String) -> [String : Any]?

    public static let liveValue = Self(
        bool: { UserDefaults.standard.bool(forKey: $0) },
        integer: { UserDefaults.standard.integer(forKey: $0) },
        string: { UserDefaults.standard.string(forKey: $0) },
        data: { UserDefaults.standard.data(forKey: $0) },
        set: { UserDefaults.standard.set($0, forKey: $1) },
        removeObject: { UserDefaults.standard.removeObject(forKey: $0) },
        register: { UserDefaults.standard.register(defaults: $0) },
        removePersistentDomain: { UserDefaults.standard.removePersistentDomain(forName: $0) },
        persistentDomain: { UserDefaults.standard.persistentDomain(forName: $0) }
    )

    public static let testValue = Self(
        bool: { _ in false },
        integer: { _ in 0 },
        string: { _ in nil },
        data: { _ in nil },
        set: { _, _ in },
        removeObject: { _ in },
        register: { _ in },
        removePersistentDomain: { _ in },
        persistentDomain: { _ in nil }
    )
}

extension UserDefaults: @retroactive @unchecked Sendable {}
