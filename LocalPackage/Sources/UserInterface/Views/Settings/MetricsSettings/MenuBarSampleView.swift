/*
 MenuBarSampleView.swift
 UserInterface

 Created by Takuto Nakamura on 2026/06/10.
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

struct MenuBarSampleView: View {
    var kind: MenuBarKind

    var body: some View {
        Canvas { context, size in
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Color(.desktop))
            )
            context.fill(
                Path(CGRect(x: 0, y: 0, width: size.width, height: 42)),
                with: .color(Color(.menubar))
            )

            // bezel
            switch kind {
            case .withNotch:
                let notch = Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 0, y: 20))
                    path.addLine(to: CGPoint(x: 20, y: 20))
                    path.addRelativeArc(
                        center: CGPoint(x: 20, y: 24),
                        radius: 4,
                        startAngle: Angle(degrees: -90),
                        delta: Angle(degrees: 90)
                    )
                    path.addLine(to: CGPoint(x: 24, y: 36))
                    path.addRelativeArc(
                        center: CGPoint(x: 28, y: 36),
                        radius: 4,
                        startAngle: Angle(degrees: 180),
                        delta: Angle(degrees: -90)
                    )
                    path.addLine(to: CGPoint(x: 132, y: 40))
                    path.addRelativeArc(
                        center: CGPoint(x: 132, y: 36),
                        radius: 4,
                        startAngle: Angle(degrees: 90),
                        delta: Angle(degrees: -90)
                    )
                    path.addLine(to: CGPoint(x: 136, y: 24))
                    path.addRelativeArc(
                        center: CGPoint(x: 140, y: 24),
                        radius: 4,
                        startAngle: Angle(degrees: 180),
                        delta: Angle(degrees: 90)
                    )
                    path.addLine(to: CGPoint(x: size.width, y: 20))
                    path.addLine(to: CGPoint(x: size.width, y: 0))
                    path.closeSubpath()
                }
                context.fill(notch, with: .color(.black))
                context.fill(
                    Path(ellipseIn: CGRect(x: 76, y: 24, width: 8, height: 8)),
                    with: .color(.gray.opacity(0.2))
                )
            case .withoutNotch:
                context.fill(
                    Path(CGRect(x: 0, y: 0, width: size.width, height: 20)),
                    with: .color(.black)
                )
            }

            // mark
            let midX = 0.5 * size.width
            context.fill(
                Path(ellipseIn: CGRect(x: midX - 10, y: 52, width: 20, height: 20)),
                with: .color(.white)
            )
            switch kind {
            case .withNotch:
                let text = Text(Image(systemName: "xmark.circle.fill"))
                    .font(.title)
                    .foregroundStyle(Color.red)
                context.draw(text, in: CGRect(x: midX - 13, y: 48, width: 26, height: 26))
            case .withoutNotch:
                let text = Text(Image(systemName: "checkmark.circle.fill"))
                    .font(.title)
                    .foregroundStyle(Color.green)
                context.draw(text, in: CGRect(x: midX - 13, y: 48, width: 26, height: 26))
            }

            let area = Path(roundedRect: CGRect(x: size.width - 220, y: 22, width: 120, height: 18), cornerRadius: 4)
            context.fill(area, with: .color(Color(.focus).opacity(0.5)))
            context.stroke(area, with: .color(Color(.focus)), style: .init(lineWidth: 1, dash: [2, 2]))

            // default icons
            context.draw(
                Image(systemName: "speaker.wave.3.fill"),
                at: CGPoint(x: size.width - 80, y: 31)
            )
            context.draw(
                Image(systemName: "magnifyingglass"),
                at: CGPoint(x: size.width - 50, y: 31)
            )
            context.draw(
                Image(systemName: "switch.2"),
                at: CGPoint(x: size.width - 20, y: 31)
            )
        }
        .frame(width: 320, height: 80)
        .border(kind.borderColor)
    }
}
