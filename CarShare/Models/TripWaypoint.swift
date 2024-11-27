import CoreLocation

struct TripWaypoint: Identifiable, Codable, Equatable {
    let id: UUID
    var coordinate: CLLocationCoordinate2D
    var address: String
    var arrivalTime: Date?
    var type: WaypointType
    
    enum WaypointType: String, Codable {
        case start
        case stop
        case end
    }
    
    init(id: UUID = UUID(), coordinate: CLLocationCoordinate2D, address: String, arrivalTime: Date? = nil, type: WaypointType) {
        self.id = id
        self.coordinate = coordinate
        self.address = address
        self.arrivalTime = arrivalTime
        self.type = type
    }
} 