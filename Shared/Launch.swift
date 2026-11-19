import Foundation

enum Launch {
    static let freePeriod = false
    static var isFree: Bool {
        #if DEBUG
        return freePeriod && !ProcessInfo.processInfo.arguments.contains { ["-paid-mode", "-paywall", "-expired"].contains($0) }
        #else
        return freePeriod
        #endif
    }
    static var supportsFixtures: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}
