import Foundation

enum SicaGame: String, CaseIterable, Identifiable {
    case freeFire, freeFireMax

    var id: String { rawValue }

    var bundleID: String {
        switch self {
        case .freeFire:    return "com.dts.freefireth"
        case .freeFireMax: return "com.dts.freefiremax"
        }
    }

    var title: String {
        switch self {
        case .freeFire:    return "FREE FIRE"
        case .freeFireMax: return "FREE FIRE MAX"
        }
    }

    var next: SicaGame {
        switch self {
        case .freeFire:    return .freeFireMax
        case .freeFireMax: return .freeFire
        }
    }
}

enum SicaFeature: String, CaseIterable, Identifiable, Codable {
    case bodyHS, neckHS, dragHS, chestHS, magicBullet

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bodyHS:      return "BODY HS"
        case .neckHS:      return "NECK HS"
        case .dragHS:      return "DRAG HS"
        case .chestHS:     return "CHEST HS"
        case .magicBullet: return "MAGIC BULLET"
        }
    }

    var payloadFolder: String {
        switch self {
        case .bodyHS:      return "BODY_HS"
        case .neckHS:      return "NECK_HS"
        case .dragHS:      return "DRAG_HS"
        case .chestHS:     return "CHEST_HS"
        case .magicBullet: return "MAGIC_BULLET"
        }
    }
}
