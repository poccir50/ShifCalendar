import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var model: ShiftMateModel
    @State private var importingSound = false

    var body: some View {
        NavigationStack {
            List {
                statusSection
                alarmSection
                soundSection
                upcomingSection
                limitsSection
            }
            .navigationTitle("ShiftMate Alarm")
            .fileImporter(isPresented: $importingSound, allowedContentTypes: [.audio], allowsMultipleSelection: false) { result in
                do {
                    guard let url = try result.get().first else { return }
                    try model.importSound(from: url)
                } catch {
                    model.statusMessage = "알람음 가져오기 실패: \(error.localizedDescription)"
                }
            }
        }
    }

    private var statusSection: some View {
        Section("현재") {
            let today = Date()
            LabeledContent("오늘 근무", value: ShiftEngine.shift(on: today).rawValue)
            if let holiday = ShiftEngine.holiday(on: today) {
                LabeledContent("회사 일정", value: holiday.name)
            }
            LabeledContent("AlarmKit 권한", value: model.authorizationText)
            LabeledContent("예약된 알람", value: "\(model.scheduledCount)개")
            if !model.statusMessage.isEmpty {
                Text(model.statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var alarmSection: some View {
        Section("실제 기상 알람") {
            DatePicker(
                "주간 기상시간",
                selection: Binding(get: { model.wakeTime }, set: { model.setWakeTime($0) }),
                displayedComponents: .hourAndMinute
            )
            .environment(\.locale, Locale(identifier: "ko_KR"))

            Button("1. 알람 권한 허용") {
                Task { await model.requestAuthorization() }
            }

            Button(model.isWorking ? "설정 중…" : "2. 근무표 기준 알람 다시 동기화") {
                Task { await model.syncAlarms() }
            }
            .disabled(model.isWorking)

            Button("15초 뒤 테스트 알람") {
                Task { await model.scheduleTestAlarm() }
            }

            Button("ShiftMate 알람 모두 해제", role: .destructive) {
                Task { await model.cancelAll() }
            }
        }
    }

    private var soundSection: some View {
        Section("알람 소리") {
            Toggle("가져온 사용자 알람음 사용", isOn: $model.useCustomSound)
                .disabled(model.customSoundFileName == nil)

            if let name = model.customSoundFileName {
                LabeledContent("현재 파일", value: name)
                    .font(.footnote)
            } else {
                Text("기본 시스템 알람음을 사용합니다.")
                    .foregroundStyle(.secondary)
            }

            Button("Files에서 알람음 가져오기") {
                importingSound = true
            }

            Text("Clock 앱에 설정된 벨소리를 다른 앱이 직접 읽을 수는 없습니다. 대신 Files의 오디오 파일을 ShiftMate 전용 알람음으로 가져올 수 있습니다. .caf / .aiff / .wav 파일을 권장합니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var upcomingSection: some View {
        Section("앞으로 3주") {
            ForEach(ShiftEngine.nextDays()) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.date.formatted(.dateTime.month().day().weekday(.abbreviated)))
                        if let holiday = item.holidayName {
                            Text(holiday).font(.caption).foregroundStyle(.red)
                        }
                    }
                    Spacer()
                    Text(item.shift.rawValue)
                        .fontWeight(.semibold)
                        .foregroundStyle(item.shift == .day ? .orange : item.shift == .night ? .blue : .secondary)
                }
            }
        }
    }

    private var limitsSection: some View {
        Section("동작 기준") {
            Text("2026-08-10 주간을 기준으로 주간/야간이 매주 교대합니다. 토·일과 등록된 2026년 회사 휴무일에는 04:50 알람을 만들지 않습니다.")
            Text("2027년 회사 달력은 아직 제공되지 않았기 때문에 이 버전은 2026-12-31까지만 자동 예약합니다.")
                .foregroundStyle(.secondary)
        }
        .font(.footnote)
    }
}
