import CoreLocation

struct SavedTrip: Identifiable, Codable {
    let id: UUID
    let carId: UUID
    let participantIds: [UUID]
    let startTime: Date
    let endTime: Date
    let distance: Double // in kilometers
    let coordinates: [CLLocationCoordinate2D]
    let startAddress: String?
    let endAddress: String?
} 