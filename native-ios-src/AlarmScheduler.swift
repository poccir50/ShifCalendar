import Foundation
import SwiftUI
import AlarmKit
import ActivityKit
import UniformTypeIdentifiers

struct ShiftMateAlarmMetadata: AlarmMetadata {}

@MainActor
final class ShiftMateModel: ObservableObject {
    @Published var wakeHour: Int { didSet { UserDefaults.standard.set(wakeHour, forKey: Keys.wakeHour) } }
    @Published var wakeMinute: Int { didSet { UserDefaults.standard.set(wakeMinute, forKey: Keys.wakeMinute) } }
    @Published var customSoundFileName: String? { didSet { UserDefaults.standard.set(customSoundFileName, forKey: Keys.customSound) } }
    @Published var useCustomSound: Bool { didSet { UserDefaults.standard.set(useCustomSound, forKey: Keys.useCustomSound) } }
    @Published var authorizationText = "확인 중"
    @Published var statusMessage = ""
    @Published var scheduledCount = 0
    @Published var isWorking = false
    private let manager = AlarmManager.shared

    init() {
        let defaults = UserDefaults.standard
        wakeHour = defaults.object(forKey: Keys.wakeHour) as? Int ?? 4
        wakeMinute = defaults.object(forKey: Keys.wakeMinute) as? Int ?? 50
        customSoundFileName = defaults.string(forKey: Keys.customSound)
        useCustomSound = defaults.object(forKey: Keys.useCustomSound) as? Bool ?? false
    }

    var wakeTime: Date {
        var comps = DateComponents(); comps.hour = wakeHour; comps.minute = wakeMinute
        return Calendar.current.date(from: comps) ?? Date()
    }
    func setWakeTime(_ date: Date) {
        wakeHour = Calendar.current.component(.hour, from: date)
        wakeMinute = Calendar.current.component(.minute, from: date)
    }

    func refreshAuthorization() async {
        switch manager.authorizationState {
        case .authorized: authorizationText = "허용됨"
        case .denied: authorizationText = "거부됨"
        case .notDetermined: authorizationText = "미설정"
        @unknown default: authorizationText = "알 수 없음"
        }
        updateScheduledCount()
    }

    func requestAuthorization() async {
        do {
            let state = try await manager.requestAuthorization()
            authorizationText = state == .authorized ? "허용됨" : "거부됨"
            statusMessage = state == .authorized ? "알람 권한이 허용되었습니다." : "알람 권한이 필요합니다. 설정에서 ShiftMate의 알람 권한을 허용해주세요."
        } catch { statusMessage = "권한 요청 실패: \(error.localizedDescription)" }
    }

    func syncAlarms(silent: Bool = false) async {
        guard manager.authorizationState == .authorized else { if !silent { statusMessage = "먼저 알람 권한을 허용해주세요." }; return }
        isWorking = true; defer { isWorking = false }
        await cancelStoredAlarms()
        let dates = ShiftEngine.eligibleWakeDates(wakeHour: wakeHour, wakeMinute: wakeMinute)
        var created: [UUID] = []; var stoppedByLimit = false
        for date in dates {
            let id = UUID()
            do { try await scheduleAlarm(id: id, date: date, title: "A조 주간근무 · 기상"); created.append(id) }
            catch AlarmManager.AlarmError.maximumLimitReached { stoppedByLimit = true; break }
            catch { statusMessage = "일부 알람 예약 실패: \(error.localizedDescription)"; break }
        }
        storeAlarmIDs(created); scheduledCount = created.count
        if !silent {
            statusMessage = stoppedByLimit ? "시스템 예약 한도까지 \(created.count)개의 실제 알람을 설정했습니다. 앱을 가끔 열면 다음 알람이 자동 보충됩니다." : "2026년 남은 주간근무일 중 \(created.count)개의 실제 알람을 설정했습니다."
        }
    }

    func scheduleTestAlarm() async {
        guard manager.authorizationState == .authorized else { statusMessage = "먼저 알람 권한을 허용해주세요."; return }
        let id = UUID(), date = Date().addingTimeInterval(15)
        do {
            try await scheduleAlarm(id: id, date: date, title: "ShiftMate 테스트 알람")
            var ids = storedAlarmIDs(); ids.append(id); storeAlarmIDs(ids); updateScheduledCount()
            statusMessage = "15초 뒤 실제 AlarmKit 테스트 알람이 울립니다."
        } catch { statusMessage = "테스트 알람 실패: \(error.localizedDescription)" }
    }

    func cancelAll() async { await cancelStoredAlarms(); scheduledCount = 0; statusMessage = "ShiftMate가 예약한 알람을 모두 해제했습니다." }

    func importSound(from url: URL) throws {
        let accessing = url.startAccessingSecurityScopedResource(); defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let sounds = library.appendingPathComponent("Sounds", isDirectory: true)
        try FileManager.default.createDirectory(at: sounds, withIntermediateDirectories: true)
        let safeName = "shiftmate-" + url.lastPathComponent.replacingOccurrences(of: " ", with: "-")
        let destination = sounds.appendingPathComponent(safeName)
        if FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.removeItem(at: destination) }
        try FileManager.default.copyItem(at: url, to: destination)
        customSoundFileName = safeName; useCustomSound = true
        statusMessage = "알람음 파일을 가져왔습니다. ‘알람 다시 동기화’를 눌러 적용하세요."
    }

    private func scheduleAlarm(id: UUID, date: Date, title: LocalizedStringResource) async throws {
        let alert = AlarmPresentation.Alert(title: title)
        let presentation = AlarmPresentation(alert: alert)
        let attributes = AlarmAttributes(presentation: presentation, metadata: ShiftMateAlarmMetadata(), tintColor: Color.orange)
        let sound: AlertConfiguration.AlertSound = {
            if useCustomSound, let name = customSoundFileName, !name.isEmpty { return .named(name) }
            return .default
        }()
        let configuration = AlarmManager.AlarmConfiguration<ShiftMateAlarmMetadata>.alarm(schedule: .fixed(date), attributes: attributes, sound: sound)
        _ = try await manager.schedule(id: id, configuration: configuration)
    }

    private func cancelStoredAlarms() async { for id in storedAlarmIDs() { try? manager.cancel(id: id) }; storeAlarmIDs([]) }
    private func updateScheduledCount() {
        do {
            let liveIDs = Set(try manager.alarms.map(\.id)); let stored = storedAlarmIDs().filter { liveIDs.contains($0) }
            storeAlarmIDs(stored); scheduledCount = stored.count
        } catch { scheduledCount = storedAlarmIDs().count }
    }
    private func storedAlarmIDs() -> [UUID] { (UserDefaults.standard.stringArray(forKey: Keys.alarmIDs) ?? []).compactMap(UUID.init(uuidString:)) }
    private func storeAlarmIDs(_ ids: [UUID]) { UserDefaults.standard.set(ids.map(\.uuidString), forKey: Keys.alarmIDs) }
    private enum Keys {
        static let wakeHour = "shiftmate.wakeHour"; static let wakeMinute = "shiftmate.wakeMinute"; static let customSound = "shiftmate.customSound"; static let useCustomSound = "shiftmate.useCustomSound"; static let alarmIDs = "shiftmate.alarmIDs"
    }
}
