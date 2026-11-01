import Foundation
import Testing
@testable import ReCopy

struct ClipClassifierTests {
    @Test(arguments: [
        ("hello world", ClipKind.text),
        ("https://trackpadrotator.lazycatlabs.com/", .link),
        ("www.apple.com", .link),
        ("dev-pm-testers@ikhlas.com", .email),
        ("mailto:hey@example.com", .email),
        ("#FF8C3C", .color),
        ("#fff", .color),
        ("rgb(255, 140, 60)", .color),
        ("hsl(24, 100%, 62%)", .color),
        ("notes.md", .text),
        ("https://example.com\nsecond line", .text),
        ("#zzzzzz", .text),
    ])
    func classifies(text: String, kind: ClipKind) {
        #expect(ClipClassifier.kind(of: text) == kind)
    }

    @Test func bareWwwGetsHttps() {
        #expect(ClipClassifier.linkURL("www.apple.com")?.absoluteString == "https://www.apple.com")
    }
}

struct ColorValueTests {
    @Test func convertsBetweenFormats() throws {
        let color = try #require(ColorValue(parsing: "#FF8C3C"))
        #expect(color.hex == "#FF8C3C")
        #expect(color.rgb == "rgb(255, 140, 60)")
        #expect(color.hsl == "hsl(25, 100%, 62%)")
        #expect(ColorValue(parsing: "hsl(0, 100%, 50%)")?.hex == "#FF0000")
    }

    @Test func keepsAlpha() throws {
        let color = try #require(ColorValue(parsing: "rgba(0, 0, 0, 0.5)"))
        #expect(color.hex == "#00000080")
        #expect(color.rgb == "rgba(0, 0, 0, 0.5)")
    }

    @Test func rejectsOutOfRange() {
        #expect(ColorValue(parsing: "rgb(300, 0, 0)") == nil)
    }
}
