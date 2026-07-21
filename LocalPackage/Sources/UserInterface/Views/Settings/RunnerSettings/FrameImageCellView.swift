/*
 FrameImageCellView.swift
 UserInterface

 Created by Takuto Nakamura on 2026/06/03.
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

struct FrameImageCellView: View {
    var index: Int
    var frameImage: FrameImage
    var isTemplate: Bool
    var isSelected: Bool

    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Image(frameImage.cgImage, scale: 1.0, label: Text("frame\(index)", bundle: .module))
                .renderingMode(isTemplate ? .template : .original)
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
            Text(verbatim: "\(index)")
                .font(.caption)
        }
        .border(isSelected ? Color.accentColor : Color.clear)
        .padding(4)
        .contentShape(.rect)
    }
}
