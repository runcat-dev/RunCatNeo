/*
 DonationProduct.swift
 DataSource

 Created by Takuto Nakamura on 2026/06/08.
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

public enum DonationProduct: String, Sendable, CaseIterable {
    case oneTime = "donation.onetime"
    case yearly = "donation.subscription.yearly"

    public var id: String {
        "com.kyome.Neo.RunCat.\(rawValue)"
    }
}
