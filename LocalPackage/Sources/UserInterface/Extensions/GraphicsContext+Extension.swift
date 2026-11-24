/*
 GraphicsContext+Extension.swift
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

import SwiftUI

extension GraphicsContext {
    mutating func drawBlackImage(origin: CGPoint, size: CGSize, @ViewBuilder image: () -> Image) {
        var resolvedImage = resolve(image())
        resolvedImage.shading = .color(.black)
        draw(resolvedImage, in: CGRect(origin: origin, size: size))
    }

    mutating func drawBlackText(origin: CGPoint, size: CGSize, @ViewBuilder text: () -> Text) {
        var resolvedText = resolve(text())
        resolvedText.shading = .color(.black)
        draw(resolvedText, in: CGRect(origin: origin, size: size))
    }

    mutating func drawIcon(systemName: String, point: CGPoint, size: CGSize) {
        var image = resolve(.init(systemName: systemName))
        image.shading = .color(.black)
        let point = CGPoint(
            x: point.x + 0.5 * size.width,
            y: point.y + 0.5 * size.height
        )
        draw(image, at: point, anchor: .center)
    }

    mutating func drawCircularGauge(origin: CGPoint, size: CGSize, ratio: Double) {
        let radius = 0.5 * min(size.width, size.height)
        let innerRadius = 0.6 * radius
        let center = CGPoint(x: origin.x + 0.5 * size.width, y: origin.y + 0.5 * size.height)
        let trackPath = Path { path in
            path.addEllipse(in: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: 2.0 * radius,
                height: 2.0 * radius
            ))
            path.addEllipse(in: CGRect(
                x: center.x - innerRadius,
                y: center.y - innerRadius,
                width: 2.0 * innerRadius,
                height: 2.0 * innerRadius
            ))
        }
        fill(trackPath, with: .color(.black.opacity(0.3)), style: FillStyle(eoFill: true))
        let startAngle = Angle.degrees(-90)
        let endAngle = Angle.degrees(-90 + 360 * ratio)
        let surfacePath = Path { path in
            path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
            path.addArc(center: center, radius: innerRadius, startAngle: endAngle, endAngle: startAngle, clockwise: true)
            path.closeSubpath()
        }
        fill(surfacePath, with: .color(.black))
    }

    mutating func drawLinearGauge(origin: CGPoint, size: CGSize, ratio: Double) {
        let trackRect = CGRect(origin: origin, size: size)
        fill(Path(roundedRect: trackRect, cornerRadius: 2.0), with: .color(.black.opacity(0.3)))
        let surfaceHeight = size.height * ratio
        let surfaceRect = CGRect(
            x: origin.x,
            y: origin.y + size.height - surfaceHeight,
            width: size.width,
            height: surfaceHeight
        )
        fill(Path(roundedRect: surfaceRect, cornerRadius: 2.0), with: .color(.black))
    }
}
