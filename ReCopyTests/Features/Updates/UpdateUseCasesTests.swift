import Foundation
import Testing
@testable import ReCopy

struct UpdateUseCasesTests {
    @Test func comparesVersionsByNumber() {
        #expect(UpdateUseCases.isNewer("0.1.10", than: "0.1.9"))
        #expect(UpdateUseCases.isNewer("v0.2.0", than: "0.1.1"))
        #expect(!UpdateUseCases.isNewer("1.0", than: "1.0.0"))
        #expect(!UpdateUseCases.isNewer("0.1.1", than: "0.1.1"))
        #expect(!UpdateUseCases.isNewer("0.1.0", than: "0.1.1"))
    }

    @Test func picksTheNewestUpdate() {
        let url = URL(string: "https://example.com")!
        let releases = ["0.1.0", "0.2.0", "0.1.2"].map { AppRelease(version: $0, notes: "", date: nil, url: url) }
        #expect(UpdateUseCases.update(in: releases, current: "0.1.1")?.version == "0.2.0")
        #expect(UpdateUseCases.update(in: releases, current: "0.2.0") == nil)
    }
}
