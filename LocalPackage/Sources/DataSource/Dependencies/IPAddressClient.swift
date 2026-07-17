/*
 IPAddressClient.swift
 DataSource

 Created by Takuto Nakamura on 2026/07/18.
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

public struct IPAddressClient: DependencyClient {
    public var localAddress: @Sendable () -> String?
    public var publicAddress: @Sendable () async -> String?

    public static let liveValue = Self(
        localAddress: {
            var addrsList: UnsafeMutablePointer<ifaddrs>?
            guard getifaddrs(&addrsList) == 0, let firstAddr = addrsList else {
                return nil
            }
            defer { freeifaddrs(addrsList) }

            var pointer: UnsafeMutablePointer<ifaddrs>? = firstAddr
            while let current = pointer {
                defer { pointer = current.pointee.ifa_next }
                let interface = current.pointee
                let flags = Int32(interface.ifa_flags)
                guard (flags & IFF_UP) == IFF_UP, (flags & IFF_LOOPBACK) == 0 else {
                    continue
                }
                guard let addr = interface.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) else {
                    continue
                }
                let name = String(cString: interface.ifa_name)
                guard name != "lo0" else {
                    continue
                }
                var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let result = getnameinfo(
                    addr,
                    socklen_t(addr.pointee.sa_len),
                    &hostBuffer,
                    socklen_t(hostBuffer.count),
                    nil,
                    0,
                    NI_NUMERICHOST
                )
                if result == 0 {
                    return String(cString: hostBuffer)
                }
            }
            return nil
        },
        publicAddress: {
            guard let url = URL(string: "https://api.ipify.org") else {
                return nil
            }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let text = String(decoding: data, as: UTF8.self)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return text.isEmpty ? nil : text
            } catch {
                return nil
            }
        }
    )

    public static let testValue = Self(
        localAddress: { "192.168.1.10" },
        publicAddress: { "203.0.113.5" }
    )
}
