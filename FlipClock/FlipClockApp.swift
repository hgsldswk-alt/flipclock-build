import SwiftUI
import StoreKit

@main
struct FlipClockApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = AppModel()
    var body: some Scene {
        WindowGroup { ClockView().environmentObject(model) }
    }
}
