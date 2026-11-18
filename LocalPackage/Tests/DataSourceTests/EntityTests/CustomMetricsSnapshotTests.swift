import Foundation
import Testing

@testable import DataSource

struct CustomMetricsSnapshotTests {
    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    @Test
    func decode_full_snapshot_with_symbol_and_metrics() throws {
        let json = """
            {
              "title": "Claude Code",
              "symbol": "staroflife",
              "metrics": [
                { "title": "Context", "formattedValue": "5.4%", "normalizedValue": 0.054 },
                { "title": "Cost", "formattedValue": "$3.21" }
              ],
              "lastUpdatedDate": "2026-06-05T04:50:40Z"
            }
            """.data(using: .utf8)!
        let snapshot = try decoder.decode(CustomMetricsSnapshot.self, from: json)
        let expected = CustomMetricsSnapshot(
            title: "Claude Code",
            symbol: "staroflife",
            metrics: [
                CustomMetric(title: "Context", formattedValue: "5.4%", normalizedValue: 0.054),
                CustomMetric(title: "Cost", formattedValue: "$3.21"),
            ],
            lastUpdatedDate: try #require(ISO8601DateFormatter().date(from: "2026-06-05T04:50:40Z"))
        )
        #expect(snapshot == expected)
    }

    @Test
    func decode_minimum_snapshot_without_symbol() throws {
        let json = """
            {
              "title": "Empty Card",
              "metrics": [], 
              "lastUpdatedDate": "2026-06-05T04:50:40Z"
            }
            """.data(using: .utf8)!
        let snapshot = try decoder.decode(CustomMetricsSnapshot.self, from: json)
        let expected = CustomMetricsSnapshot(
            title: "Empty Card",
            lastUpdatedDate: try #require(ISO8601DateFormatter().date(from: "2026-06-05T04:50:40Z"))
        )
        #expect(snapshot == expected)
    }

    @Test
    func decode_snapshot_with_metricsBarValue() throws {
        let json = """
            {
              "title": "Claude Code",
              "metricsBarValue": "5.4%",
              "metrics": [],
              "lastUpdatedDate": "2026-06-05T04:50:40Z"
            }
            """.data(using: .utf8)!
        let snapshot = try decoder.decode(CustomMetricsSnapshot.self, from: json)
        let expected = CustomMetricsSnapshot(
            title: "Claude Code",
            metricsBarValue: "5.4%",
            lastUpdatedDate: try #require(ISO8601DateFormatter().date(from: "2026-06-05T04:50:40Z"))
        )
        #expect(snapshot == expected)
    }

    @Test
    func decode_snapshot_with_metric_detail_and_state() throws {
        let json = """
            {
              "title": "Sessions",
              "metrics": [
                {
                  "title": "Build dashboard",
                  "formattedValue": "Waiting",
                  "detail": "/Users/example/project",
                  "state": "waiting"
                }
              ],
              "lastUpdatedDate": "2026-06-05T04:50:40Z"
            }
            """.data(using: .utf8)!
        #expect(
            try decoder.decode(CustomMetricsSnapshot.self, from: json) == CustomMetricsSnapshot(
                title: "Sessions",
                metrics: [
                    CustomMetric(
                        title: "Build dashboard",
                        formattedValue: "Waiting",
                        detail: "/Users/example/project",
                        state: .waiting
                    ),
                ],
                lastUpdatedDate: try #require(ISO8601DateFormatter().date(from: "2026-06-05T04:50:40Z"))
            )
        )
    }

    @Test
    func decode_throws_when_title_missing() {
        let json = """
            {
              "metrics": [],
              "lastUpdatedDate": "2026-06-05T04:50:40Z"
            }
            """.data(using: .utf8)!
        #expect(throws: DecodingError.self) {
            _ = try decoder.decode(CustomMetricsSnapshot.self, from: json)
        }
    }

    @Test
    func decode_throws_when_lastUpdatedDate_missing() {
        let json = """
            { 
              "title": "Card",
              "metrics": []
            }
            """.data(using: .utf8)!
        #expect(throws: DecodingError.self) {
            _ = try decoder.decode(CustomMetricsSnapshot.self, from: json)
        }
    }

    @Test
    func decode_throws_on_invalid_json() {
        let json = "{ not json }".data(using: .utf8)!
        #expect(throws: (any Error).self) {
            _ = try decoder.decode(CustomMetricsSnapshot.self, from: json)
        }
    }

    @Test
    func roundtrip_preserves_values() throws {
        let original = CustomMetricsSnapshot(
            title: "GPU",
            symbol: "cpu",
            metricsBarValue: "64°C",
            metrics: [
                CustomMetric(title: "Temp", formattedValue: "64°C", normalizedValue: 0.64),
                CustomMetric(title: "Fan", formattedValue: "1200 RPM"),
            ],
            lastUpdatedDate: Date(timeIntervalSince1970: 1800000000)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(CustomMetricsSnapshot.self, from: data)
        #expect(decoded == original)
    }
}
