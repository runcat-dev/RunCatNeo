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

@MainActor private let thumbnailCache = NSCache<NSString, NSImage>()

extension RunnerBundle {
    @MainActor var thumbnail: Image {
        if let nsImage = thumbnailImage {
            Image(nsImage: nsImage)
        } else {
            Image(systemName: "questionmark.square")
        }
    }

    @MainActor private var thumbnailImage: NSImage? {
        let key = runner.id as NSString
        if let cachedImage = thumbnailCache.object(forKey: key) {
            return cachedImage
        }
        guard case let .thumbnail(frame) = displayFormat,
              let thumbnailImage = frame.nsImage?.trailingAlignedBitmap(width: 50, height: 18) else {
            return nil
        }
        thumbnailImage.isTemplate = runner.isTemplate
        thumbnailCache.setObject(thumbnailImage, forKey: key)
        return thumbnailImage
    }
}

private extension NSImage {
    func trailingAlignedBitmap(width: CGFloat, height: CGFloat) -> NSImage? {
        guard size.height > 0,
              let pixelsHigh = representations.first?.pixelsHigh,
              pixelsHigh > 0,
              let bitmapImageRep = NSBitmapImageRep(
                  bitmapDataPlanes: nil,
                  pixelsWide: Int(width * CGFloat(pixelsHigh) / height),
                  pixelsHigh: pixelsHigh,
                  bitsPerSample: 8,
                  samplesPerPixel: 4,
                  hasAlpha: true,
                  isPlanar: false,
                  colorSpaceName: .deviceRGB,
                  bytesPerRow: .zero,
                  bitsPerPixel: .zero
              ) else {
            return nil
        }
        bitmapImageRep.size = NSSize(width: width, height: height)
        let drawingWidth = size.width * height / size.height
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapImageRep)
        draw(in: NSRect(x: width - drawingWidth, y: .zero, width: drawingWidth, height: height))
        NSGraphicsContext.restoreGraphicsState()
        let image = NSImage(size: bitmapImageRep.size)
        image.addRepresentation(bitmapImageRep)
        return image
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
