/*
 CustomMetricsSourceRowView.swift
 UserInterface

 Created by Takuto Nakamura on 2026/06/06.
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

struct CustomMetricsSourceRowView: View {
    private let controlWidth: CGFloat = 24
    private let controlSpacing: CGFloat = 8

    var source: CustomMetricsSource
    var isErrorDetected: Bool
    var dragStarted: () -> Void
    var removeButtonTapped: () async -> Void
    var sourceLinkTapped: () async -> Void

    var body: some View {
        LabeledContent {
            HStack(spacing: controlSpacing) {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.secondary)
                    .frame(width: controlWidth)
                Button(role: .destructive) {
                    Task {
                        await removeButtonTapped()
                    }
                } label: {
                    Image(systemName: "minus.circle")
                        .foregroundStyle(Color.red)
                }
                .buttonStyle(.borderless)
                .frame(width: controlWidth)
            }
        } label: {
            Text(source.displayName)
                .truncationMode(.middle)
            HStack(spacing: 8) {
                Text(LocalizedStringKey(stringLiteral: "\(source.fileURL.relativePath) [→](/)"))
                    .environment(\.openURL, OpenURLAction { _ in
                        Task {
                            await sourceLinkTapped()
                        }
                        return .handled
                    })
                if isErrorDetected {
                    Text("errorDetected", bundle: .module)
                        .foregroundStyle(Color.yellow)
                }
            }
        }
        .contentShape(
            .interaction,
            CustomMetricsSourceDragHandleShape(
                width: controlWidth,
                trailingInset: controlWidth + controlSpacing
            )
        )
        .contentShape(.dragPreview, Rectangle())
        .onDrag {
            dragStarted()
            return NSItemProvider(object: source.id.uuidString as NSString)
        }
    }
}

private struct CustomMetricsSourceDragHandleShape: Shape {
    var width: CGFloat
    var trailingInset: CGFloat

    func path(in rect: CGRect) -> Path {
        Path(CGRect(
            x: rect.maxX - trailingInset - width,
            y: rect.minY,
            width: width,
            height: rect.height
        ))
    }
}
