import Foundation

enum ShiftKind: String, Codable, CaseIterable {
    case day = "주간"
    case night = "야간"
    case off = "휴무"
}

struct CompanyHoliday: Hashable, Codable, Identifiable {
    var id: String { "\(start)-\(end)-\(name)" }
    let start: String
    let end: String
    let name: String
}

struct ShiftDay: Identifiable, Hashable {
    let date: Date
    let shift: ShiftKind
    let holidayName: String?
    var id: Date { date }
}

enum ShiftEngine {
    static let baseDate = ISO8601DateFormatter.localDate("2026-08-10")!

    static let holidays2026: [CompanyHoliday] = [
        .init(start: "2026-01-01", end: "2026-01-02", name: "신정휴무"),
        .init(start: "2026-02-16", end: "2026-02-19", name: "설날휴무"),
        .init(start: "2026-03-01", end: "2026-03-01", name: "삼일절"),
        .init(start: "2026-05-01", end: "2026-05-01", name: "근로자의날"),
        .init(start: "2026-05-04", end: "2026-05-04", name: "근무일조정 휴무"),
        .init(start: "2026-05-05", end: "2026-05-05", name: "어린이날"),
        .init(start: "2026-05-24", end: "2026-05-24", name: "석가탄신일"),
        .init(start: "2026-05-25", end: "2026-05-25", name: "대체휴일 · 회사창립기념일"),
        .init(start: "2026-06-03", end: "2026-06-03", name: "지방선거"),
        .init(start: "2026-06-06", end: "2026-06-06", name: "현충일"),
        .init(start: "2026-07-17", end: "2026-07-17", name: "제헌절"),
        .init(start: "2026-08-03", end: "2026-08-07", name: "하기휴무"),
        .init(start: "2026-08-15", end: "2026-08-15", name: "광복절"),
        .init(start: "2026-08-17", end: "2026-08-17", name: "대체휴일"),
        .init(start: "2026-09-24", end: "2026-09-28", name: "추석휴무"),
        .init(start: "2026-10-03", end: "2026-10-03", name: "개천절"),
        .init(start: "2026-10-05", end: "2026-10-05", name: "대체휴일"),
        .init(start: "2026-10-09", end: "2026-10-09", name: "한글날"),
        .init(start: "2026-10-24", end: "2026-10-24", name: "노조창립일"),
        .init(start: "2026-12-25", end: "2026-12-25", name: "성탄절")
    ]

    static func holiday(on date: Date, calendar: Calendar = .current) -> CompanyHoliday? {
        let key = date.yyyyMMdd
        return holidays2026.first { key >= $0.start && key <= $0.end }
    }

    static func shift(on date: Date, calendar: Calendar = .current) -> ShiftKind {
        if holiday(on: date, calendar: calendar) != nil { return .off }
        let weekday = calendar.component(.weekday, from: date)
        if weekday == 1 || weekday == 7 { return .off }

        let monday = startOfWeekMonday(for: date, calendar: calendar)
        let baseMonday = startOfWeekMonday(for: baseDate, calendar: calendar)
        let days = calendar.dateComponents([.day], from: baseMonday, to: monday).day ?? 0
        let weeks = Int(floor(Double(days) / 7.0))
        return abs(weeks % 2) == 0 ? .day : .night
    }

    static func nextDays(from start: Date = Date(), count: Int = 21) -> [ShiftDay] {
        let cal = Calendar.current
        var result: [ShiftDay] = []
        for offset in 0..<count {
            guard let d = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: start)) else { continue }
            let holiday = holiday(on: d, calendar: cal)
            result.append(.init(date: d, shift: shift(on: d, calendar: cal), holidayName: holiday?.name))
        }
        return result
    }

    static func eligibleWakeDates(from now: Date = Date(), wakeHour: Int, wakeMinute: Int, horizonDays: Int = 180) -> [Date] {
        let cal = Calendar.current
        var result: [Date] = []
        let finalDate = ISO8601DateFormatter.localDate("2026-12-31")!
        for offset in 0...horizonDays {
            guard let day = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: now)), day <= finalDate else { break }
            guard shift(on: day, calendar: cal) == .day else { continue }
            guard let alarmDate = cal.date(bySettingHour: wakeHour, minute: wakeMinute, second: 0, of: day), alarmDate > now else { continue }
            result.append(alarmDate)
        }
        return result
    }

    private static func startOfWeekMonday(for date: Date, calendar: Calendar) -> Date {
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        let delta = weekday == 1 ? -6 : 2 - weekday
        return calendar.date(byAdding: .day, value: delta, to: day)!
    }
}

extension Date {
    var yyyyMMdd: String {
        Self.localDateFormatter.string(from: self)
    }

    var shortKorean: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 (E) HH:mm"
        return f.string(from: self)
    }

    private static let localDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

extension ISO8601DateFormatter {
    static func localDate(_ string: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: string)
    }
}
