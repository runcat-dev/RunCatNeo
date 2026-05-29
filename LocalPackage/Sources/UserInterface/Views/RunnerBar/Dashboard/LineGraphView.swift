/*
 LineGraphView.swift
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

struct LineGraphView: View {
    var values: [Double]

    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 16))
            values.enumerated().forEach { offset, value in
                let v = min(100, max(2, value))
                path.addLine(to: CGPoint(x: 2.0 * CGFloat(offset), y: 16 - 0.16 * v))
            }
            path.addLine(to: CGPoint(x: 120, y: 16))
            path.closeSubpath()
        }
        .fill(Color.accentColor)
        .frame(width: 120, height: 16)
    }
}
