/*
 MetricsBarView.swift
 UserInterface

 Created by Takuto Nakamura on 2026/05/24.
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
import SystemInfoKit

struct MetricsBarView: View {
    @StateObject var store: MetricsBar

    private var size: CGSize {
        var widthArray = [CGFloat]()
        let iconWidth = IndicatorKind.categoryIcon.size.width
        if store.metricsBarConfiguration.showsCPU, store.systemInfoBundle.cpuInfo != nil {
            widthArray.append(iconWidth + IndicatorKind.usageFullLabel.size.width)
        }
        if store.metricsBarConfiguration.showsMemory, store.systemInfoBundle.memoryInfo != nil {
            widthArray.append(iconWidth + IndicatorKind.usageFullLabel.size.width)
        }
        if store.metricsBarConfiguration.showsStorage, store.systemInfoBundle.storageInfo != nil {
            widthArray.append(iconWidth + IndicatorKind.usageFullLabel.size.width)
        }
        if store.metricsBarConfiguration.showsBattery, let batteryInfo = store.systemInfoBundle.batteryInfo {
            widthArray.append(iconWidth)
            if batteryInfo.isInstalled {
                widthArray.append(IndicatorKind.usageFullLabel.size.width)
            }
        }
        if store.metricsBarConfiguration.showsNetwork, store.systemInfoBundle.networkInfo != nil {
            widthArray.append(iconWidth + IndicatorKind.usageHalfLabel.size.width)
        }
        for bundle in store.customMetricsBundles where store.metricsBarConfiguration.showsCustomMetrics(of: bundle.id) {
            widthArray.append(iconWidth + IndicatorKind.customValueLabelSize(for: bundle.metricsBarLabel).width)
        }
        let width = if widthArray.isEmpty {
            IndicatorKind.sleepingCat.size.width
        } else {
            widthArray.joined(separator: IndicatorKind.spacer.size.width)
        }
        return CGSize(width: width, height: 18)
    }

    var body: some View {
        Image(size: size) { context in
            if store.metricsBarConfiguration.isEmpty {
                context.drawBlackImage(origin: .zero, size: IndicatorKind.sleepingCat.size) {
                    Image(.sleepingCat)
                }
            } else {
                var point = CGPoint(x: 0, y: 1)
                if store.metricsBarConfiguration.showsCPU, let cpuInfo = store.systemInfoBundle.cpuInfo {
                    drawSystemInfo(context: &context, point: &point, systemInfo: cpuInfo)
                }
                if store.metricsBarConfiguration.showsMemory, let memoryInfo = store.systemInfoBundle.memoryInfo {
                    drawSystemInfo(context: &context, point: &point, systemInfo: memoryInfo)
                }
                if store.metricsBarConfiguration.showsStorage, let storageInfo = store.systemInfoBundle.storageInfo {
                    drawSystemInfo(context: &context, point: &point, systemInfo: storageInfo)
                }
                if store.metricsBarConfiguration.showsBattery, let batteryInfo = store.systemInfoBundle.batteryInfo {
                    drawSystemInfo(context: &context, point: &point, systemInfo: batteryInfo)
                }
                if store.metricsBarConfiguration.showsNetwork, let networkInfo = store.systemInfoBundle.networkInfo {
                    drawSystemInfo(context: &context, point: &point, systemInfo: networkInfo)
                }
                for bundle in store.customMetricsBundles where store.metricsBarConfiguration.showsCustomMetrics(of: bundle.id) {
                    drawCustomMetrics(context: &context, point: &point, bundle: bundle)
                }
            }
        }
        .renderingMode(.template)
        .task {
            await store.send(.task(String(describing: Self.self)))
        }
    }

    private func drawSystemInfo(
        context: inout GraphicsContext,
        point: inout CGPoint,
        systemInfo: any SystemInfo
    ) {
        let iconSize = IndicatorKind.categoryIcon.size
        context.drawIcon(systemName: systemInfo.icon, point: point, size: iconSize)
        point.x += iconSize.width

        switch systemInfo {
        case is CPUInfo, is MemoryInfo, is StorageInfo:
            context.drawBlackText(origin: point, size: IndicatorKind.usageFullLabel.size) {
                Text(verbatim: systemInfo.percentage.menuBarDescription)
            }
            point.x += IndicatorKind.usageFullLabel.size.width + IndicatorKind.spacer.size.width

        case let batteryInfo as BatteryInfo:
            if batteryInfo.isInstalled {
                context.drawBlackText(origin: point, size: IndicatorKind.usageFullLabel.size) {
                    Text(verbatim: batteryInfo.percentage.menuBarDescription)
                }
                point.x += IndicatorKind.usageFullLabel.size.width
            }
            point.x += IndicatorKind.spacer.size.width

        case let networkInfo as NetworkInfo:
            let labelSize = IndicatorKind.usageHalfLabel.size
            context.drawBlackText(origin: CGPoint(x: point.x, y: 1), size: labelSize) {
                Text(verbatim: "\u{2B06}\(networkInfo.upload.menuBarDescription(type: .network))")
                    .font(.system(size: 7))
                    .monospaced()
            }
            context.drawBlackText(origin: CGPoint(x: point.x, y: 9), size: labelSize) {
                Text(verbatim: "\u{2B07}\(networkInfo.download.menuBarDescription(type: .network))")
                    .font(.system(size: 7))
                    .monospaced()
            }
        default:
            break
        }
    }

    private func drawCustomMetrics(
        context: inout GraphicsContext,
        point: inout CGPoint,
        bundle: CustomMetricsBundle
    ) {
        let iconSize = IndicatorKind.categoryIcon.size
        context.drawIcon(systemName: bundle.snapshot.displaySymbol, point: point, size: iconSize)
        point.x += iconSize.width
        let labelSize = IndicatorKind.customValueLabelSize(for: bundle.metricsBarLabel)
        context.drawBlackText(origin: point, size: labelSize) {
            Text(verbatim: bundle.metricsBarLabel)
                .monospacedDigit()
        }
        point.x += labelSize.width + IndicatorKind.spacer.size.width
    }
}

extension MetricsBar: ObservableObject {}
