import Foundation
import Testing
@testable import ReCopy

struct ClipUseCasesTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func copyingAgainCountsInsteadOfDuplicating() {
        let capture = Capture(content: .text("hello"), sourceName: "Arc", sourceBundleID: "company.thebrowser.Browser")
        let first = ClipUseCases.record(capture, in: [], device: "Mac", now: now)
        #expect(first.isNew)
        let later = now.addingTimeInterval(60)
        let second = ClipUseCases.record(capture, in: [first.item], device: "Mac", now: later)
        #expect(!second.isNew)
        #expect(second.item.id == first.item.id)
        #expect(second.item.copyCount == 2)
        #expect(second.item.lastCopied == later)
        #expect(second.item.firstCopied == now)
    }

    @Test func recordsKindFromText() {
        let item = ClipUseCases.record(Capture(content: .text("  https://apple.com  ")), in: [], device: "Mac", now: now).item
        #expect(item.kind == .link)
        #expect(item.text == "https://apple.com")
    }

    @Test func pasteCountsAndDates() {
        var item = ClipUseCases.record(Capture(content: .text("x")), in: [], device: "Mac", now: now).item
        item = ClipUseCases.markPasted(item, now: now.addingTimeInterval(10))
        item = ClipUseCases.markPasted(item, now: now.addingTimeInterval(20))
        #expect(item.pasteCount == 2)
        #expect(item.firstPasted == now.addingTimeInterval(10))
        #expect(item.lastPasted == now.addingTimeInterval(20))
    }

    @Test func expiryKeepsPinned() {
        let old = now.addingTimeInterval(-100 * 86_400)
        var pinned = ClipItem(kind: .text, text: "a", hash: "a", firstCopied: old, lastCopied: old)
        pinned.pinned = true
        let stale = ClipItem(kind: .text, text: "b", hash: "b", firstCopied: old, lastCopied: old)
        let fresh = ClipItem(kind: .text, text: "c", hash: "c", firstCopied: now, lastCopied: now)
        #expect(ClipUseCases.expired([pinned, stale, fresh], retention: .threeMonths, now: now).map(\.text) == ["b"])
        #expect(ClipUseCases.expired([stale], retention: .forever, now: now).isEmpty)
    }

    @Test func filtersByKindAndQuery() {
        let link = ClipItem(kind: .link, text: "https://apple.com", hash: "1", firstCopied: now, lastCopied: now)
        var image = ClipItem(kind: .image, hash: "2", firstCopied: now, lastCopied: now)
        image.recognizedText = "Invoice total"
        #expect(ClipUseCases.filter([link, image], type: .kind(.link), query: "").count == 1)
        #expect(ClipUseCases.filter([link, image], type: nil, query: "invoice").first?.kind == .image)
    }

    @Test func filtersCodeAmongTextEntries() {
        let code = ClipItem(kind: .text, text: "git status", hash: "1", firstCopied: now, lastCopied: now)
        let prose = ClipItem(kind: .text, text: "See you at 5", hash: "2", firstCopied: now, lastCopied: now)
        let link = ClipItem(kind: .link, text: "https://apple.com", hash: "3", firstCopied: now, lastCopied: now)
        let isCode = { (item: ClipItem) in item.text.flatMap(TextFormatter.language) != nil }
        #expect(ClipUseCases.filter([code, prose, link], type: .code, query: "", isCode: isCode).map(\.hash) == ["1"])
        #expect(ClipUseCases.filter([code, prose, link], type: .kind(.text), query: "", isCode: isCode).count == 2,
                "Code is still text")
        #expect(TypeFilter.all.prefix(2) == [.kind(.text), .code], "Code comes right after Text")
    }

    @Test func filtersByGroup() {
        let work = UUID()
        var inWork = ClipItem(kind: .text, text: "a", hash: "a", firstCopied: now, lastCopied: now)
        inWork.groupID = work
        let loose = ClipItem(kind: .text, text: "b", hash: "b", firstCopied: now, lastCopied: now)
        #expect(ClipUseCases.filter([inWork, loose], type: nil, query: "", group: work).map(\.text) == ["a"])
        #expect(ClipUseCases.filter([inWork, loose], type: nil, query: "", group: nil).count == 2)
    }

    @Test func filtersByCreationDate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let today = ClipItem(kind: .text, hash: "t", firstCopied: now, lastCopied: now)
        let yesterday = now.addingTimeInterval(-86_400)
        // Created yesterday but copied again today: the filter goes by creation.
        let older = ClipItem(kind: .text, hash: "y", firstCopied: yesterday, lastCopied: now)
        let lastMonth = ClipItem(kind: .text, hash: "m", firstCopied: now.addingTimeInterval(-20 * 86_400), lastCopied: now)
        let items = [today, older, lastMonth]
        let filter = { (created: DateFilter) in
            ClipUseCases.filter(items, type: nil, query: "", created: created, now: now, calendar: calendar).map(\.hash)
        }
        #expect(filter(.today) == ["t"])
        #expect(filter(.yesterday) == ["y"])
        #expect(filter(.last7Days) == ["t", "y"])
        #expect(filter(.last30Days).count == 3)
        #expect(filter(.anyTime).count == 3)
    }

    @Test func sectionsPutPinnedFirstThenByDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let yesterday = now.addingTimeInterval(-86_400)
        var pinned = ClipItem(kind: .text, hash: "p", firstCopied: yesterday, lastCopied: yesterday)
        pinned.pinned = true
        let today = ClipItem(kind: .text, hash: "t", firstCopied: now, lastCopied: now)
        let older = ClipItem(kind: .text, hash: "y", firstCopied: yesterday, lastCopied: yesterday)
        let sections = ClipUseCases.sections([older, pinned, today], now: now, calendar: calendar)
        #expect(sections.map(\.0) == [.pinned, .today, .yesterday])
    }
}
