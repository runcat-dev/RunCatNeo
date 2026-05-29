/*
 RunnerLayer.swift
 UserInterface

 Created by Takuto Nakamura on 2026/05/08.
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

import AppKit

final class RunnerLayer: CALayer {
    private var gap: CGFloat
    private var width = CGFloat.zero
    private let maskLayer = CALayer()
    private var keyFrameAnimation = CAKeyframeAnimation(keyPath: "contents")

    init(gap: CGFloat) {
        self.gap = gap
        super.init()
        contentsGravity = CALayerContentsGravity.left
        masksToBounds = true
        contentsScale = 2.0
        maskLayer.frame = bounds
        keyFrameAnimation.calculationMode = .discrete
        keyFrameAnimation.repeatCount = .infinity
        keyFrameAnimation.isRemovedOnCompletion = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setFrames(_ frames: [NSImage], _ isTemplate: Bool) {
        let size = frames.first?.alignmentRect.size ?? .zero
        keyFrameAnimation.values = frames
        keyFrameAnimation.duration = Double(frames.count) / 2.0
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        removeAllAnimations()
        maskLayer.removeAllAnimations()
        frame = CGRect(origin: CGPoint(x: gap, y: 2.0), size: size)
        maskLayer.frame = CGRect(origin: .zero, size: size)
        if isTemplate {
            if mask == nil {
                maskLayer.speed = speed
            }
            timeOffset = .zero
            beginTime = .zero
            speed = 1.0
            mask = maskLayer
            maskLayer.add(keyFrameAnimation, forKey: "running")
        } else {
            if mask != nil {
                speed = maskLayer.speed
            }
            mask = nil
            add(keyFrameAnimation, forKey: "running")
        }
        CATransaction.commit()
    }

    func setColor(_ tintColor: CGColor, _ isTemplate: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        backgroundColor = isTemplate ? tintColor : nil
        CATransaction.commit()
    }

    func setSpeed(_ speed: Float) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if mask == nil {
            timeOffset = convertTime(CACurrentMediaTime(), from: nil)
            beginTime = CACurrentMediaTime()
            self.speed = speed
        } else {
            maskLayer.timeOffset = maskLayer.convertTime(CACurrentMediaTime(), from: nil)
            maskLayer.beginTime = CACurrentMediaTime()
            maskLayer.speed = speed
        }
        CATransaction.commit()
    }
}
