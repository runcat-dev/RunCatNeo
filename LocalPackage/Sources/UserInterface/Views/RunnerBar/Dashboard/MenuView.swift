/*
 MenuView.swift
 UserInterface

 Created by Takuto Nakamura on 2026/05/23.
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
import Model
import SwiftUI

struct MenuView: View {
    @Environment(\.openWindow) private var openWindow
    var store: DashboardMenu

    private var aboutBody: AttributedString {
        var attributedString = AttributedString()

        var ossParagraph = AttributedString(String(localized: "oss", bundle: .module) + "\n")
        ossParagraph.foregroundColor = NSColor.textColor
        attributedString.append(ossParagraph)

        let url = URL.github
        var urlParagraph = AttributedString(url.absoluteString)
        urlParagraph.foregroundColor = NSColor.linkColor
        urlParagraph.link = url
        attributedString.append(urlParagraph)

        return attributedString
    }

    var body: some View {
        Menu {
            Picker(selection: Binding<Runner?>(
                get: { store.currentRunner },
                asyncSet: { await store.send(.runnerKindPickerSelected($0)) }
            )) {
                ForEach(store.runnerBundleList, id: \.runner) { runnerBundle in
                    Label {
                        Text(runnerBundle.runner.formatted)
                    } icon: {
                        runnerBundle.thumbnail
                    }
                    .tag(runnerBundle.runner)
                }
            } label: {
                Label {
                    Text("runner", bundle: .module)
                } icon: {
                    Image(systemName: "pawprint.fill")
                }
            }
            Divider()
            SettingsLink {
                Label {
                    Text("settings", bundle: .module)
                } icon: {
                    Image(systemName: "gear")
                }
            }
            .buttonStyle(.preAction {
                await store.send(.settingsButtonTapped)
            })
            Button {
                Task {
                    await store.send(.activityMonitorButtonTapped)
                }
            } label: {
                Label {
                    Text("openActivityMonitor", bundle: .module)
                } icon: {
                    Image(.activityMonitor)
                }
            }
            Divider()
            Button {
                Task {
                    await store.send(.aboutButtonTapped(aboutBody))
                }
            } label: {
                Label {
                    Text("about\(store.appName)", bundle: .module)
                } icon: {
                    Image(systemName: "info.circle")
                }
            }
            Button {
                Task {
                    await store.send(.openSourceLicenseButtonTapped(.init(action: {
                        openWindow(id: $0, value: $1)
                    })))
                }
            } label: {
                Label {
                    Text("openSourceLicense", bundle: .module)
                } icon: {
                    Image(systemName: "building.columns")
                }
            }
            Button {
                Task {
                    await store.send(.reportIssueButtonTapped)
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
                    await store.send(.quitButtonTapped)
                }
            } label: {
                Label {
                    Text("quit\(store.appName)", bundle: .module)
                } icon: {
                    Image(systemName: "xmark.rectangle")
                }
            }
            .accessibilityIdentifier("terminate_app")
            if !store.isPreview, isDebugBuild {
                Divider()
                Button {
                    Task {
                        await store.send(.debugSleepButtonTapped)
                    }
                } label: {
                    Label {
                        Text("debugSleep", bundle: .module)
                    } icon: {
                        Image(systemName: "sleep")
                    }
                }
                Button {
                    Task {
                        await store.send(.debugWakeUpButtonTapped)
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
                Image(systemName: "list.bullet")
            }
            .labelStyle(.iconOnly)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .task {
            await store.send(.viewAppeared)
        }
        .onDisappear {
            Task {
                await store.send(.viewDisappeared)
            }
        }
    }
}
