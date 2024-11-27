import Foundation

enum TripZone: String, CaseIterable, Codable {
    case oslo = "Oslo"
    case akershus = "Akershus"
    case other = "Other"
    
    var ratePerKm: Double {
        switch self {
        case .oslo:
            return 3.5
        case .akershus:
            return 4.0
        case .other:
            return 4.5
        }
    }
} 