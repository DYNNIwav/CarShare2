import Foundation
import CoreLocation
import MapKit

@MainActor
class CommonLocationsViewModel: ObservableObject {
    @Published var locations: [CommonLocation] = []
    
    private let userDefaults = UserDefaults.standard
    private let locationsKey = "commonLocations"
    
    init() {
        loadLocations()
    }
    
    private func loadLocations() {
        if let data = userDefaults.data(forKey: locationsKey),
           let locations = try? JSONDecoder().decode([CommonLocation].self, from: data) {
            self.locations = locations
        }
    }
    
    private func saveLocations() {
        if let data = try? JSONEncoder().encode(locations) {
            userDefaults.set(data, forKey: locationsKey)
        }
    }
    
    func addLocation(_ location: CommonLocation) {
        locations.append(location)
        saveLocations()
    }
    
    func removeLocation(at indexSet: IndexSet) {
        locations.remove(atOffsets: indexSet)
        saveLocations()
    }
    
    func moveLocation(from source: IndexSet, to destination: Int) {
        locations.move(fromOffsets: source, toOffset: destination)
        saveLocations()
    }
    
    // Helper method to get locations as a dictionary for MapDistanceView
    var locationsDictionary: [String: String] {
        Dictionary(uniqueKeysWithValues: locations.map { ($0.name, $0.address) })
    }
} 