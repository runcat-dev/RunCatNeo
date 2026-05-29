/*
 MenuView.swift
 UserInterface

 Created by Takuto Nakamura on 2026/05/23.
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
import Model
import SwiftUI

struct MenuView: View {
    var appName: String
    var buttonTapped: (Dashboard.Action) async -> Void

    private var aboutBody: AttributedString {
        var attributedString = AttributedString()

        var ossParagraph = AttributedString(String(localized: "oss", bundle: .module))
        ossParagraph.foregroundColor = NSColor.textColor
        attributedString.append(ossParagraph)

        let url = URL(string: .gitHubURL)!
        var urlParagraph = AttributedString(url.absoluteString)
        urlParagraph.foregroundColor = NSColor(resource: .url)
        urlParagraph.link = url
        attributedString.append(urlParagraph)

        return attributedString
    }

    var body: some View {
        Menu {
            SettingsLink {
                Label {
                    Text("settings", bundle: .module)
                } icon: {
                    Image(systemName: "gear")
                }
            }
            .buttonStyle(.preAction {
                await buttonTapped(.settingsButtonTapped)
            })
            Button {
                Task {
                    await buttonTapped(.activityMonitorButtonTapped)
                }
            } label: {
                Label {
                    Text("openActivityMonitor", bundle: .module)
                } icon: {
                    Image(systemName: "waveform.path.ecg")
                }
            }
            Divider()
            Button {
                Task {
                    await buttonTapped(.aboutButtonTapped(aboutBody))
                }
            } label: {
                Label {
                    Text("about\(appName)", bundle: .module)
                } icon: {
                    Image(systemName: "info.circle")
                }
            }
            Button {
                Task {
                    await buttonTapped(.reportIssueButtonTapped)
                }
            } label: {
                Label {
                    Text("reportIssue", bundle: .module)
                } icon: {
                    Image(systemName: "envelope")
                }
            }
            Button {
                Task {
                    await buttonTapped(.quitButtonTapped)
                }
            } label: {
                Label {
                    Text("quit\(appName)", bundle: .module)
                } icon: {
                    Image(systemName: "xmark.rectangle")
                }
            }
            .accessibilityIdentifier("terminate_app")
            if isDebugBuild {
                Divider()
                Button {
                    Task {
                        await buttonTapped(.debugSleepButtonTapped)
                    }
                } label: {
                    Label {
                        Text("debugSleep", bundle: .module)
                    } icon: {
                        Image(systemName: "powersleep")
                    }
                }
                Button {
                    Task {
                        await buttonTapped(.debugWakeUpButtonTapped)
                    }
                } label: {
                    Label {
                        Text("debugWakeUp", bundle: .module)
                    } icon: {
                        Image(systemName: "wake")
                    }
                }
            }
        } label: {
            Label {
                Text("menu", bundle: .module)
            } icon: {
                Image(systemName: "line.3.horizontal.circle")
            }
            .labelStyle(.iconOnly)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
    }
}

#Preview {
    MenuView(appName: "RunCat Neo", buttonTapped: { _ in })
}
