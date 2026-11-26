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
}
