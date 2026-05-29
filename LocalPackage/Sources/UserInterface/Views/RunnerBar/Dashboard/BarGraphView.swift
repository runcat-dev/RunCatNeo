/*
 BarGraphView.swift
 UserInterface

 Created by Takuto Nakamura on 2026/05/09.
 Copyright 2026 Koyme22 (Takuto Nakamura)

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

struct BarGraphView: View {
    var value: Double

    var body: some View {
        Rectangle()
            .frame(width: 120, height: 8)
            .foregroundStyle(Color.clear)
            .border(Color.accentColor, width: 0.5)
            .overlay(alignment: .leading) {
                Rectangle()
                    .frame(width: 120 * min(100, value) / 100, height: 8)
                    .foregroundStyle(Color.accentColor)
            }
    }
}
