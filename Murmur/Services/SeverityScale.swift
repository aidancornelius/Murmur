import Foundation

struct SeverityScale {
    static func descriptor(for value: Int) -> String {
        switch max(1, min(5, value)) {
        case 1: return "Stable"
        case 2: return "Manageable"
        case 3: return "Challenging"
        case 4: return "Severe"
        default: return "Crisis"
        }
    }
}
