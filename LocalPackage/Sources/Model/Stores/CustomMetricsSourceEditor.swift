/*
 CustomMetricsSourceEditor.swift
 Model

 Created by Takuto Nakamura on 2026/11/26.
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
import Foundation
import Observation

@MainActor @Observable
public final class CustomMetricsSourceEditor: Composable, Identifiable {
    private let logService: LogService
    private let customMetricsService: CustomMetricsService

    public let id: UUID
    public let mode: EditorMode<CustomMetricsSource>
    public var source: CustomMetricsSource?
    public var snapshot: CustomMetricsSnapshot?
    public var symbolImageData: Data?
    public var showingSourceFileImporter: Bool
    public var showingSymbolImageFileImporter: Bool
    public var showingSymbolImageGuidancePopover: Bool
    public var showingAlert: Bool
    public var error: RCNError?
    public let action: (Action) async -> Void

    public var canConfirm: Bool {
        source != nil
    }

    public var previewBundle: CustomMetricsBundle? {
        guard let source, let snapshot else { return nil }
        return .init(id: source.id, snapshot: snapshot, symbolImageData: symbolImageData)
    }

    public init(
        _ appDependencies: AppDependencies,
        id: UUID,
        mode: EditorMode<CustomMetricsSource> = .add,
        source: CustomMetricsSource? = nil,
        snapshot: CustomMetricsSnapshot? = nil,
        symbolImageData: Data? = nil,
        showingSourceFileImporter: Bool = false,
        showingSymbolImageFileImporter: Bool = false,
        showingSymbolImageGuidancePopover: Bool = false,
        showingAlert: Bool = false,
        error: RCNError? = nil,
        action: @escaping (Action) async -> Void = { _ in }
    ) {
        self.logService = .init(appDependencies)
        self.customMetricsService = .init(appDependencies)
        self.id = id
        self.mode = mode
        self.source = source
        self.snapshot = snapshot
        self.symbolImageData = symbolImageData
        self.showingSourceFileImporter = showingSourceFileImporter
        self.showingSymbolImageFileImporter = showingSymbolImageFileImporter
        self.showingSymbolImageGuidancePopover = showingSymbolImageGuidancePopover
        self.showingAlert = showingAlert
        self.error = error
        self.action = action
    }

    public func reduce(_ action: Action) async {
        switch action {
        case .chooseSourceButtonTapped:
            showingSourceFileImporter = true

        case let .sourceFileImporterResponse(.success(urls)):
            guard let url = urls.first else { return }
            do {
                var (source, snapshot) = try customMetricsService.makeSource(of: url)
                if let editingSource = mode.editingTarget {
                    source.id = editingSource.id
                    source.createdAt = editingSource.createdAt
                }
                self.source = source
                self.snapshot = snapshot
            } catch let error as RCNError {
                await send(.errorOccurred(error))
            } catch {
                logService.error(.importingCustomMetricsSourceFailed(error))
            }

        case let .sourceFileImporterResponse(.failure(error)):
            logService.error(.importingCustomMetricsSourceFailed(error))

        case .chooseSymbolImageButtonTapped:
            showingSymbolImageFileImporter = true

        case let .symbolImageFileImporterResponse(.success(urls)):
            guard let url = urls.first else { return }
            do {
                symbolImageData = try customMetricsService.loadSymbolImageData(of: url)
            } catch let error as RCNError {
                await send(.errorOccurred(error))
            } catch {
                logService.error(.importingSymbolImageFailed(error))
            }

        case let .symbolImageFileImporterResponse(.failure(error)):
            logService.error(.importingSymbolImageFailed(error))

        case .removeSymbolImageButtonTapped:
            symbolImageData = nil

        case .symbolImageGuidanceButtonTapped:
            showingSymbolImageGuidancePopover = true

        case .confirmButtonTapped:
            guard let source else { return }
            do {
                switch mode {
                case .add:
                    try customMetricsService.add(source: source, symbolImageData: symbolImageData)
                case .edit:
                    try customMetricsService.update(source: source, symbolImageData: symbolImageData)
                }
                await send(.customMetricsSourceSaved)
            } catch let error as RCNError {
                await send(.errorOccurred(error))
            } catch {
                logService.critical(.unknown(error))
            }

        case .customMetricsSourceSaved:
            return

        case .cancelButtonTapped:
            return

        case let .errorOccurred(error):
            self.error = error
            showingAlert = true
        }
    }

    public enum Action: Sendable {
        case chooseSourceButtonTapped
        case sourceFileImporterResponse(Result<[URL], any Error>)
        case chooseSymbolImageButtonTapped
        case symbolImageFileImporterResponse(Result<[URL], any Error>)
        case removeSymbolImageButtonTapped
        case symbolImageGuidanceButtonTapped
        case confirmButtonTapped
        case customMetricsSourceSaved
        case cancelButtonTapped
        case errorOccurred(RCNError)
    }
}
