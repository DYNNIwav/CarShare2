import Foundation
import CoreLocation
import MapKit

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var error: String?
    private let locationManager = LocationManager()
    
    func addLocation(name: String, address: String, to commonLocationsViewModel: CommonLocationsViewModel) async {
        do {
            // Try MKLocalSearch first for better results
            let searchRequest = MKLocalSearch.Request()
            searchRequest.naturalLanguageQuery = address
            searchRequest.region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 59.9139, longitude: 10.7522), // Oslo center
                span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)
            )
            
            let search = MKLocalSearch(request: searchRequest)
            let response = try await search.start()
            
            if let firstResult = response.mapItems.first {
                let placemark = firstResult.placemark
                let formattedAddress = [
                    placemark.thoroughfare,
                    placemark.subThoroughfare,
                    placemark.locality,
                    placemark.postalCode,
                    placemark.country
                ].compactMap { $0 }.joined(separator: " ")
                
                let location = CommonLocation(
                    name: name,
                    address: formattedAddress.isEmpty ? address : formattedAddress
                )
                commonLocationsViewModel.addLocation(location)
            } else {
                throw NSError(
                    domain: "LocationError",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Could not validate the address. Please try a more specific address."]
                )
            }
        } catch {
            self.error = "Could not validate the address: \(error.localizedDescription). Please try a more specific address."
        }
    }
} 