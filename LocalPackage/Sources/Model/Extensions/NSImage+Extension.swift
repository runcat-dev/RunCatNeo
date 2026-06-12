/*
 NSImage+Extension.swift
 Model

 Created by Takuto Nakamura on 2026/05/11.
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
import CoreImage.CIFilterBuiltins

extension NSImage {
    var ciImage: CIImage? {
        guard let data = tiffRepresentation else { return nil }
        return CIImage(data: data)
    }

    var plane: NSImage {
        guard let ciImage else { return self }
        let rep = NSCIImageRep(ciImage: ciImage)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
        return nsImage
    }

    public func normalize() {
        let scale = size.height / 18.0
        size = CGSize(width: size.width / scale, height: size.height / scale)
    }

    func flip() {
        let filter = CIFilter.perspectiveRotate()
        filter.inputImage = ciImage
        filter.pitch = .pi
        guard let output = filter.outputImage else { return }
        let rep = NSCIImageRep(ciImage: output)
        representations.forEach { removeRepresentation($0) }
        addRepresentation(rep)
    }

    public func resize(width: CGFloat, alignment: HorizontalAlignment = .center) {
        guard let ciImage, size.height > 0, width > 0 else { return }
        let pixelHeight = ciImage.extent.height
        let scale = pixelHeight / size.height
        let sourcePixelWidth = ciImage.extent.width
        let targetPixelWidth = width * scale
        let delta = targetPixelWidth - sourcePixelWidth
        let pixelOffsetX: CGFloat = switch alignment {
        case .leading: 0
        case .center: delta / 2
        case .trailing: delta
        }
        let translated = ciImage.transformed(
            by: CGAffineTransform(translationX: pixelOffsetX, y: 0)
        )
        let canvasRect = CGRect(x: 0, y: 0, width: targetPixelWidth, height: pixelHeight)
        let canvas = CIImage(color: CIColor.clear).cropped(to: canvasRect)
        let output = translated.composited(over: canvas).cropped(to: canvasRect)
        let rep = NSCIImageRep(ciImage: output)
        representations.forEach { removeRepresentation($0) }
        addRepresentation(rep)
        size = CGSize(width: width, height: size.height)
    }

    public enum HorizontalAlignment {
        case leading
        case center
        case trailing
    }
}
