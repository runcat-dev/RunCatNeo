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

import AppKit
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

    mutating func drawBoltIcon(point: CGPoint, size: CGSize) {
        var resolvedText = resolve(Text(Image(systemName: "bolt.fill")).font(.system(size: size.height * 0.7)))
        resolvedText.shading = .color(.black)
        draw(resolvedText, in: CGRect(origin: point, size: size))
    }

    mutating func drawUsageBar(origin: CGPoint, size: CGSize, percentage: Double) {
        let outlineRect = CGRect(origin: origin, size: size)
        stroke(Path(roundedRect: outlineRect, cornerRadius: 1), with: .color(.black), lineWidth: 1)
        let fillHeight = (size.height - 2) * (min(max(percentage, 0), 100) / 100)
        let fillRect = CGRect(
            x: origin.x + 1,
            y: origin.y + size.height - 1 - fillHeight,
            width: size.width - 2,
            height: fillHeight
        )
        fill(Path(fillRect), with: .color(.black))
    }

    mutating func drawUsagePieChart(origin: CGPoint, size: CGSize, percentage: Double) {
        let clamped = min(max(percentage, 0), 100)
        let center = CGPoint(x: origin.x + size.width / 2, y: origin.y + size.height / 2)
        let radius = min(size.width, size.height) / 2 - 1
        let angle = (clamped / 100) * 360

        stroke(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)), with: .color(.black), lineWidth: 1)

        if clamped >= 99.5 {
            fill(Path(ellipseIn: CGRect(x: center.x - (radius - 1), y: center.y - (radius - 1), width: (radius - 1) * 2, height: (radius - 1) * 2)), with: .color(.black))
        } else if clamped > 0 {
            var path = Path()
            path.move(to: center)
            let endAngle = Angle(degrees: -90 + angle)
            let startAngle = Angle(degrees: -90)
            path.addArc(center: center, radius: radius - 1, startAngle: startAngle, endAngle: endAngle, clockwise: false)
            path.closeSubpath()
            fill(path, with: .color(.black))
        }
    }

    mutating func drawBatteryIndicator(origin: CGPoint, size: CGSize, percentage: Double, isCharging: Bool) {
        let clamped = min(max(percentage, 0), 100)
        let bodyWidth = size.width * 0.75
        let bodyHeight = size.height * 0.6
        let bodyRect = CGRect(
            x: origin.x + (size.width - bodyWidth) / 2,
            y: origin.y + (size.height - bodyHeight) / 2,
            width: bodyWidth,
            height: bodyHeight
        )
        let terminalRect = CGRect(
            x: bodyRect.maxX,
            y: bodyRect.midY - size.height * 0.15,
            width: size.width * 0.15,
            height: size.height * 0.3
        )

        fill(Path(roundedRect: bodyRect, cornerRadius: 1), with: .color(.black))
        fill(Path(terminalRect), with: .color(.black))

        let fontSize = size.height * 0.45
        let font = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .semibold)
        let numberString = "\(Int(clamped))"
        let textSize = NSAttributedString(string: numberString, attributes: [.font: font]).size()
        var resolvedText = resolve(
            Text(verbatim: numberString).font(.system(size: fontSize, weight: .semibold)).monospacedDigit()
        )
        resolvedText.shading = .color(.black)

        let boltSize = CGSize(width: fontSize * 0.7, height: fontSize * 0.9)
        let boltWidth = isCharging ? boltSize.width : 0
        let boltGap: CGFloat = isCharging ? 1 : 0
        let contentWidth = boltWidth + boltGap + textSize.width
        let contentOriginX = bodyRect.midX - contentWidth / 2
        let textOrigin = CGPoint(x: contentOriginX + boltWidth + boltGap, y: bodyRect.midY - textSize.height / 2)

        // The final image is displayed with .renderingMode(.template), which discards color and
        // keeps only alpha — drawing the number (and bolt) in a different color on top of the solid
        // fill would stay fully opaque and disappear. Punching them out with .destinationOut instead
        // leaves transparent gaps in the fill, which is what actually reads as visible.
        blendMode = .destinationOut
        draw(resolvedText, in: CGRect(origin: textOrigin, size: textSize))
        if isCharging {
            var resolvedBolt = resolve(Text(Image(systemName: "bolt.fill")).font(.system(size: fontSize * 0.85)))
            resolvedBolt.shading = .color(.black)
            let boltOrigin = CGPoint(x: contentOriginX, y: bodyRect.midY - boltSize.height / 2)
            draw(resolvedBolt, in: CGRect(origin: boltOrigin, size: boltSize))
        }
        blendMode = .normal
    }
}
