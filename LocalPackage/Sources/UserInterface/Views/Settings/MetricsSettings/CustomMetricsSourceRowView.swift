/*
 CustomMetricsSourceRowView.swift
 UserInterface

 Created by Takuto Nakamura on 2026/06/06.
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

import DataSource
import SwiftUI

struct CustomMetricsSourceRowView: View {
    var source: CustomMetricsSource
    var isErrorDetected: Bool
    var removeButtonTapped: () async -> Void
    var sourceLinkTapped: () async -> Void

    var body: some View {
        LabeledContent {
            Button(role: .destructive) {
                Task {
                    await removeButtonTapped()
                }
            } label: {
                Image(systemName: "minus.circle")
                    .foregroundStyle(Color.red)
            }
            .buttonStyle(.borderless)
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
    }
}
