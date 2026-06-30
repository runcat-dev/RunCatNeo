/*
 URL+Extension.swift
 Model

 Created by Takuto Nakamura on 2026/06/09.
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

extension URL {
    public static let github = URL(
        string: "https://github.com/runcat-dev/RunCatNeo"
    )!

    public static var githubIssues: URL {
        Self.github.appending(path: "issues")
    }

    public static var customMetricsSchema: URL {
        Self.github.appending(path: "blob/main/docs/CustomMetricsSchema.md")
    }

    public static let runnerGallery = URL(
        string: "https://runcat-dev.github.io/RunnerGallery/"
    )!

    public static let termsOfService = URL(
        string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
    )!

    public static let privacyPolicy = URL(
        string: "https://runcat-dev.github.io/RunCatNeo/privacy_policy.html"
    )!

    public static let manageSubscriptions = URL(
        string: "itms-apps://apps.apple.com/account/subscriptions"
    )!
}
