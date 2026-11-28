import Foundation
import Testing

@testable import Model

struct URLExtensionTests {
    @Test
    func runnerGallery_appends_language_code_as_lang_query() {
        let url = URL.runnerGallery(languageCode: "zh-Hans")
        #expect(url.absoluteString == "https://runcat-dev.github.io/RunnerGallery/?lang=zh-Hans")
    }

    @Test
    func runnerGallery_omits_lang_query_without_language_code() {
        let url = URL.runnerGallery(languageCode: nil)
        #expect(url.absoluteString == "https://runcat-dev.github.io/RunnerGallery/")
    }
}
