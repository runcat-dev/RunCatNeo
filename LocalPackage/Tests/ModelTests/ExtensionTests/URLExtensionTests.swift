import Foundation
import Testing

@testable import Model

struct URLExtensionTests {
    @Test
    func runnerGallery_appends_language_code_as_lang_query() {
        #expect(
            URL.runnerGallery(languageCode: "zh-Hans").absoluteString
                == "https://runcat-dev.github.io/RunnerGallery/?lang=zh-Hans"
        )
    }

    @Test
    func runnerGallery_omits_lang_query_without_language_code() {
        #expect(
            URL.runnerGallery(languageCode: nil).absoluteString
                == "https://runcat-dev.github.io/RunnerGallery/"
        )
    }
}
