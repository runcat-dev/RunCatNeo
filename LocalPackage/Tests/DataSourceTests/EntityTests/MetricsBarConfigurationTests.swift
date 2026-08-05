import Foundation
import Testing

@testable import DataSource

struct MetricsBarConfigurationTests {
    @Test
    func decode_defaults_to_percentage_valueStyle_when_key_missing() throws {
        let json = """
            {
              "showsCPU" : true,
              "showsMemory" : false,
              "showsStorage" : false,
              "showsBattery" : false,
              "showsNetwork" : false,
              "visibleCustomMetricsSourceIDs" : []
            }
            """.data(using: .utf8)!
        let configuration = try JSONDecoder().decode(MetricsBarConfiguration.self, from: json)
        #expect(configuration.resolvedValueStyle == .percentage)
    }

    @Test
    func resolvedValueStyle_returns_pie_when_set() {
        var configuration = MetricsBarConfiguration.default
        configuration.valueStyle = .pie
        #expect(configuration.resolvedValueStyle == .pie)
    }

    @Test
    func roundtrip_preserves_valueStyle() throws {
        var original = MetricsBarConfiguration.default
        original.valueStyle = .bar
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MetricsBarConfiguration.self, from: data)
        #expect(decoded == original)
    }

    @Test
    func decode_defaults_to_percentage_batteryStyle_when_key_missing() throws {
        let json = """
            {
              "showsCPU" : true,
              "showsMemory" : false,
              "showsStorage" : false,
              "showsBattery" : false,
              "showsNetwork" : false,
              "visibleCustomMetricsSourceIDs" : [],
              "valueStyle" : "bar"
            }
            """.data(using: .utf8)!
        let configuration = try JSONDecoder().decode(MetricsBarConfiguration.self, from: json)
        #expect(configuration.resolvedBatteryStyle == .percentage)
    }

    @Test
    func resolvedBatteryStyle_returns_compact_when_set() {
        var configuration = MetricsBarConfiguration.default
        configuration.batteryStyle = .compact
        #expect(configuration.resolvedBatteryStyle == .compact)
    }

    @Test
    func roundtrip_preserves_batteryStyle() throws {
        var original = MetricsBarConfiguration.default
        original.batteryStyle = .compact
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MetricsBarConfiguration.self, from: data)
        #expect(decoded == original)
    }
}
