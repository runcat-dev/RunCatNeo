/*
 RunnerPreviewView.swift
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

import Model
import SwiftUI

struct RunnerPreviewView: View {
    @Bindable var store: CustomRunnerSettings

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Group {
                if let frameImage = store.previewingFrameImage {
                    Image(frameImage.cgImage, scale: 1.0, label: Text("preview", bundle: .module))
                        .renderingMode(store.isTemplate ? .template : .original)
                        .resizable()
                        .scaledToFit()
                } else {
                    Color.clear
                }
            }
            .frame(width: 100, height: 36)
            .padding(4)
            .border(Color(.separatorColor))
            Slider(value: $store.previewSpeed, in: 0 ... 3, step: 1) {
                EmptyView()
            } minimumValueLabel: {
                Image(systemName: "tortoise.fill")
            } maximumValueLabel: {
                Image(systemName: "hare.fill")
            }
            .labelsHidden()
        }
    }
}
