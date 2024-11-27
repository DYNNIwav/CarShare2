import CoreLocation

struct TripData: Codable, Identifiable {
    let id: UUID
    let coordinates: [CLLocationCoordinate2D]
    let startTime: Date
    let endTime: Date
    let startAddress: String?
    let endAddress: String?
    
    init(coordinates: [CLLocationCoordinate2D], startTime: Date, endTime: Date, startAddress: String? = nil, endAddress: String? = nil) {
        self.id = UUID()
        self.coordinates = coordinates
        self.startTime = startTime
        self.endTime = endTime
        self.startAddress = startAddress
        self.endAddress = endAddress
    }
}

// Add Codable conformance for CLLocationCoordinate2D
extension CLLocationCoordinate2D: Codable {
    enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        self.init(latitude: latitude, longitude: longitude)
    }
} 