import Foundation
import CoreLocation

@MainActor
class TripTrackingViewModel: ObservableObject {
    @Published var selectedCar: Car?
    @Published var selectedParticipants: Set<Participant> = []
    @Published var isShowingCarSelection = false
    @Published var isShowingParticipantSelection = false
    @Published var savedTrips: [SavedTrip] = []
    @Published var error: String?
    @Published var waypoints: [TripWaypoint] = []
    
    private let carShareViewModel: CarShareViewModel
    
    init(carShareViewModel: CarShareViewModel) {
        self.carShareViewModel = carShareViewModel
        loadSavedTrips()
    }
    
    func saveTrip(_ tripData: TripData) {
        guard let car = selectedCar else {
            error = "Please select a car for this trip"
            return
        }
        
        guard !selectedParticipants.isEmpty else {
            error = "Please select at least one participant"
            return
        }
        
        // Calculate trip distance from waypoints
        var totalDistance: Double = 0
        for i in 0..<waypoints.count - 1 {
            let start = CLLocation(latitude: waypoints[i].coordinate.latitude,
                                 longitude: waypoints[i].coordinate.longitude)
            let end = CLLocation(latitude: waypoints[i + 1].coordinate.latitude,
                               longitude: waypoints[i + 1].coordinate.longitude)
            totalDistance += end.distance(from: start)
        }
        
        let savedTrip = SavedTrip(
            id: UUID(),
            carId: car.id,
            participantIds: Array(selectedParticipants.map { $0.id }),
            startTime: tripData.startTime,
            endTime: tripData.endTime,
            distance: totalDistance / 1000, // Convert to kilometers
            coordinates: tripData.coordinates,
            startAddress: waypoints.first?.address,
            endAddress: waypoints.last?.address
        )
        
        savedTrips.append(savedTrip)
        saveTripsToDisk()
        
        // Reset selection
        selectedCar = nil
        selectedParticipants.removeAll()
        waypoints.removeAll()
    }
    
    func addWaypoint(_ waypoint: TripWaypoint) {
        waypoints.append(waypoint)
    }
    
    func removeWaypoint(at index: Int) {
        waypoints.remove(at: index)
    }
    
    func moveWaypoint(from source: IndexSet, to destination: Int) {
        waypoints.move(fromOffsets: source, toOffset: destination)
    }
    
    private func loadSavedTrips() {
        if let data = UserDefaults.standard.data(forKey: "savedTrips"),
           let decoded = try? JSONDecoder().decode([SavedTrip].self, from: data) {
            savedTrips = decoded
        }
    }
    
    private func saveTripsToDisk() {
        if let encoded = try? JSONEncoder().encode(savedTrips) {
            UserDefaults.standard.set(encoded, forKey: "savedTrips")
        }
    }
} 