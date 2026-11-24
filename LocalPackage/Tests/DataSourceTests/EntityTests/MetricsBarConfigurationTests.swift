import Foundation
import Testing

@testable import DataSource

struct MetricsBarConfigurationTests {
    @Test
    func decode_configuration_without_styles_falls_back_to_percentage() throws {
        let json = """
            {
              "showsCPU": true,
              "showsMemory": true,
              "showsStorage": true,
              "showsBattery": false,
              "showsNetwork": false,
              "visibleCustomMetricsSourceIDs": []
            }
            """.data(using: .utf8)!
        #expect(
            try JSONDecoder().decode(MetricsBarConfiguration.self, from: json) == MetricsBarConfiguration(
                showsCPU: true,
                cpuStyle: .percentage,
                showsMemory: true,
                memoryStyle: .percentage,
                showsStorage: true,
                storageStyle: .percentage,
                showsBattery: false,
                showsNetwork: false,
                visibleCustomMetricsSourceIDs: []
            )
        )
    }

    @Test
    func decode_configuration_with_unknown_style_falls_back_to_percentage_only_for_that_style() throws {
        let json = """
            {
              "showsCPU": true,
              "cpuStyle": "sparkline",
              "showsMemory": true,
              "memoryStyle": "circularGauge",
              "showsStorage": true,
              "storageStyle": "availableCapacity",
              "showsBattery": false,
              "showsNetwork": false,
              "visibleCustomMetricsSourceIDs": []
            }
            """.data(using: .utf8)!
        #expect(
            try JSONDecoder().decode(MetricsBarConfiguration.self, from: json) == MetricsBarConfiguration(
                showsCPU: true,
                cpuStyle: .percentage,
                showsMemory: true,
                memoryStyle: .circularGauge,
                showsStorage: true,
                storageStyle: .availableCapacity,
                showsBattery: false,
                showsNetwork: false,
                visibleCustomMetricsSourceIDs: []
            )
        )
    }

    @Test
    func encode_then_decode_preserves_styles() throws {
        let configuration = MetricsBarConfiguration(
            showsCPU: true,
            cpuStyle: .linearGauge,
            showsMemory: false,
            memoryStyle: .circularGauge,
            showsStorage: true,
            storageStyle: .usedCapacity,
            showsBattery: true,
            showsNetwork: false,
            visibleCustomMetricsSourceIDs: [try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))]
        )
        let data = try JSONEncoder().encode(configuration)
        #expect(try JSONDecoder().decode(MetricsBarConfiguration.self, from: data) == configuration)
    }
}
