import Foundation

/// The headings the history is grouped under: pinned entries first, then by when they were last copied.
nonisolated enum TimeSection: Hashable, Sendable {
    case pinned, today, yesterday, thisWeek, thisMonth
    case month(year: Int, month: Int)

    static func of(_ date: Date, now: Date, calendar: Calendar = .current) -> TimeSection {
        if calendar.isDate(date, inSameDayAs: now) { return .today }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return .yesterday
        }
        if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) { return .thisWeek }
        if calendar.isDate(date, equalTo: now, toGranularity: .month) { return .thisMonth }
        let parts = calendar.dateComponents([.year, .month], from: date)
        return .month(year: parts.year ?? 0, month: parts.month ?? 0)
    }

    var title: String {
        switch self {
        case .pinned: L(.sectionPinned)
        case .today: L(.sectionToday)
        case .yesterday: L(.sectionYesterday)
        case .thisWeek: L(.sectionThisWeek)
        case .thisMonth: L(.sectionThisMonth)
        case let .month(year, month):
            DateComponents(calendar: .current, year: year, month: month, day: 1).date?
                .formatted(.dateTime.month(.wide).year()) ?? ""
        }
    }
}
