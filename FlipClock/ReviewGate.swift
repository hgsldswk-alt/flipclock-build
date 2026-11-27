import Foundation

enum ReviewEvent { case completedPomodoro, generatedShare }
enum ReviewGate {
    static func claim(event: ReviewEvent, version: String, data: inout AppData) -> Bool {
        let eligible = event == .generatedShare ? !data.didShare : data.completedPomodoros == 3
        if event == .generatedShare { data.didShare = true }
        guard eligible, !data.reviewedVersions.contains(version) else { return false }
        data.reviewedVersions.append(version); return true
    }
}
