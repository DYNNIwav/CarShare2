import Foundation

enum TripZone: String, CaseIterable, Codable {
    case osloBaerum = "Oslo + Bærum (0-50km)"
    case localOther = "Other Local (0-50km)"
    case regional = "Regional (50-250km)"
    case longDistance = "Long Distance (250-500km)"
    case extended = "Extended (500+km)"
    
    var ratePerKm: Double {
        switch self {
        case .osloBaerum: return 4.5
        case .localOther: return 3.0
        case .regional: return 2.5
        case .longDistance: return 2.2
        case .extended: return 1.8
        }
    }
} 