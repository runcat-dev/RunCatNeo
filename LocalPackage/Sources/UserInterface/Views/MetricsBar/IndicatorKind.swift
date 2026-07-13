/*
 IndicatorKind.swift
 UserInterface

 Created by Takuto Nakamura on 2026/05/25.
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

import AppKit

enum IndicatorKind {
    case sleepingCat
    case categoryIcon
    case spacer
    case usageFullLabel
    case usageHalfLabel

    var size: CGSize {
        switch self {
        case .sleepingCat:
            CGSize(width: 28.0, height: 18.0)
        case .categoryIcon:
            CGSize(width: 22.0, height: 16.0)
        case .spacer:
            CGSize(width: 4.0, height: 18.0)
        case .usageFullLabel:
            CGSize(width: 40.0, height: 16.0)
        case .usageHalfLabel:
            CGSize(width: 46.0, height: 8.0)
        }
    }

    static let customValueLabelMaxWidth = 80.0

    static func customValueLabelSize(for text: String) -> CGSize {
        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let measuredWidth = NSAttributedString(string: text, attributes: [.font: font]).size().width
        let width = min(ceil(measuredWidth) + 4.0, customValueLabelMaxWidth)
        return CGSize(width: width, height: 16.0)
    }
}
