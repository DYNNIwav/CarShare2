import CoreLocation
import MapKit

@MainActor
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var startLocation: CLLocationCoordinate2D?
    @Published var endLocation: CLLocationCoordinate2D?
    @Published var route: MKRoute?
    @Published var distance: Double = 0
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var error: String?
    
    private let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        if #available(iOS 14.0, *) {
            authorizationStatus = locationManager.authorizationStatus
        } else {
            authorizationStatus = CLLocationManager.authorizationStatus()
        }
    }
    
    func requestLocationPermission() {
        if authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            if #available(iOS 14.0, *) {
                locationManager.requestTemporaryFullAccuracyAuthorization(
                    withPurposeKey: "NSLocationUsageDescription"
                )
            }
        }
    }
    
    func requestAlwaysPermission() {
        locationManager.requestAlwaysAuthorization()
    }
    
    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    // MARK: - CLLocationManagerDelegate
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            if #available(iOS 14.0, *) {
                authorizationStatus = manager.authorizationStatus
            } else {
                authorizationStatus = CLLocationManager.authorizationStatus()
            }
            
            switch authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                if #available(iOS 14.0, *) {
                    manager.requestTemporaryFullAccuracyAuthorization(
                        withPurposeKey: "NSLocationUsageDescription"
                    )
                }
                manager.startUpdatingLocation()
            case .denied, .restricted:
                error = "Location access denied"
                stopUpdatingLocation()
            default:
                break
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        Task { @MainActor in
            currentLocation = location.coordinate
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    self.error = "Location services are disabled"
                case .locationUnknown:
                    self.error = "Unable to determine location"
                default:
                    self.error = error.localizedDescription
                }
            } else {
                self.error = error.localizedDescription
            }
        }
    }
    
    // MARK: - Geocoding and Route Calculation
    
    func geocodeAddress(_ address: String) async throws -> CLLocationCoordinate2D {
        let geocoder = CLGeocoder()
        let placemarks = try await geocoder.geocodeAddressString(address)
        
        guard let location = placemarks.first?.location?.coordinate else {
            throw LocationError.invalidAddress
        }
        
        return location
    }
    
    func calculateRoute() async throws {
        guard let start = startLocation,
              let end = endLocation else {
            throw LocationError.missingLocations
        }
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: end))
        request.transportType = .automobile
        
        let directions = MKDirections(request: request)
        let response = try await directions.calculate()
        
        guard let route = response.routes.first else {
            throw LocationError.routeNotFound
        }
        
        self.route = route
        self.distance = route.distance
    }
    
    enum LocationError: LocalizedError {
        case invalidAddress
        case missingLocations
        case routeNotFound
        
        var errorDescription: String? {
            switch self {
            case .invalidAddress:
                return "Invalid address provided"
            case .missingLocations:
                return "Start or end location is missing"
            case .routeNotFound:
                return "Could not find a route between the locations"
            }
        }
    }
} 
