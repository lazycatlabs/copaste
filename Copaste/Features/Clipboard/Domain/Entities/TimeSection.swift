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

/// The clipboard window's date filter: entries first copied (created) in this period.
nonisolated enum DateFilter: String, CaseIterable, Sendable {
    case anyTime, today, yesterday, last7Days, last30Days, thisYear

    /// The period, or nil for any time.
    func interval(now: Date, calendar: Calendar = .current) -> DateInterval? {
        let startOfToday = calendar.startOfDay(for: now)
        let start: Date?
        var end = now
        switch self {
        case .anyTime: return nil
        case .today: start = startOfToday
        case .yesterday:
            start = calendar.date(byAdding: .day, value: -1, to: startOfToday)
            end = startOfToday
        case .last7Days: start = calendar.date(byAdding: .day, value: -6, to: startOfToday)
        case .last30Days: start = calendar.date(byAdding: .day, value: -29, to: startOfToday)
        case .thisYear: start = calendar.dateInterval(of: .year, for: now)?.start
        }
        return start.map { DateInterval(start: $0, end: max($0, end)) }
    }

    var title: String {
        switch self {
        case .anyTime: L(.dateFilterAnyTime)
        case .today: L(.sectionToday)
        case .yesterday: L(.sectionYesterday)
        case .last7Days: L(.dateFilterLast7Days)
        case .last30Days: L(.dateFilterLast30Days)
        case .thisYear: L(.dateFilterThisYear)
        }
    }
}
