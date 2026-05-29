/*
 GraphicsContext+Extension.swift
 UserInterface

 Created by Takuto Nakamura on 2026/05/25.
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
}
