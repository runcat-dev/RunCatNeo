/*
 RunnerBundle+Extension.swift
 UserInterface

 Created by Takuto Nakamura on 2026/05/31.
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

import DataSource
import SwiftUI

extension RunnerBundle {
    var thumbnail: Image {
        if case let .thumbnail(frame) = displayFormat, let nsImage = frame.nsImage {
            nsImage.normalize()
            nsImage.resize(width: 50, alignment: .trailing)
            nsImage.isTemplate = runner.isTemplate
            return Image(nsImage: nsImage)
        } else {
            return Image(systemName: "questionmark.square")
        }
    }
}

private extension Frame {
    var nsImage: NSImage? {
        switch self {
        case let .preset(resourceName):
            NSImage(resource: .init(name: resourceName, bundle: .module))
        case let .custom(data):
            NSImage(data: data)
        case .broken:
            nil
        }
    }
}
