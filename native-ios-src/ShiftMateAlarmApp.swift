import SwiftUI

@main
struct ShiftMateAlarmApp: App {
    @StateObject private var model = ShiftMateModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .task {
                    await model.refreshAuthorization()
                    if model.authorizationText == "허용됨" {
                        await model.syncAlarms(silent: true)
                    }
                }
        }
    }
}
