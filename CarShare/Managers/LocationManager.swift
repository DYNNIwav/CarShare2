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
    @Published var isTracking = false
    @Published var currentTrip: [CLLocationCoordinate2D] = []
    @Published var tripStartTime: Date?
    @Published var tripEndTime: Date?
    @Published var waypoints: [TripWaypoint] = []
    @Published var routeSegments: [MKRoute] = []
    @Published var totalDistance: Double = 0
    private var tripTimer: Timer?
    
    private let locationManager = CLLocationManager()
    private var isTrackingLocation = false
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update every 10 meters
        locationManager.allowsBackgroundLocationUpdates = false // Set to true if you need background updates
        locationManager.pausesLocationUpdatesAutomatically = false
        
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
        guard !isTrackingLocation else { return }
        
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            isTrackingLocation = true
            locationManager.startUpdatingLocation()
            
            // Request full accuracy if available
            if #available(iOS 14.0, *) {
                locationManager.requestTemporaryFullAccuracyAuthorization(
                    withPurposeKey: "NSLocationUsageDescription"
                )
            }
        case .notDetermined:
            requestLocationPermission()
        default:
            error = "Location access is required to use this feature"
        }
    }
    
    func stopUpdatingLocation() {
        isTrackingLocation = false
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
                // Only start updating if we were trying to track location
                if isTrackingLocation {
                    manager.startUpdatingLocation()
                }
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
        
        // Only use accurate locations
        guard location.horizontalAccuracy >= 0 && location.horizontalAccuracy <= 100 else { return }
        
        Task { @MainActor in
            currentLocation = location.coordinate
            
            if isTracking {
                // Add location to current trip if we're actively tracking
                // and the user has moved more than 10 meters
                if let lastLocation = currentTrip.last {
                    let lastCLLocation = CLLocation(latitude: lastLocation.latitude, longitude: lastLocation.longitude)
                    let distance = location.distance(from: lastCLLocation)
                    if distance > 10 {
                        currentTrip.append(location.coordinate)
                    }
                } else {
                    currentTrip.append(location.coordinate)
                }
            }
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
    
    func calculateRouteWithWaypoints() async throws {
        guard waypoints.count >= 2 else {
            throw LocationError.insufficientWaypoints
        }
        
        routeSegments = []
        totalDistance = 0
        
        // Calculate routes between consecutive waypoints
        for i in 0..<(waypoints.count - 1) {
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: waypoints[i].coordinate))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: waypoints[i + 1].coordinate))
            request.transportType = .automobile
            
            let directions = MKDirections(request: request)
            let response = try await directions.calculate()
            
            guard let route = response.routes.first else {
                throw LocationError.routeNotFound
            }
            
            routeSegments.append(route)
            totalDistance += route.distance
        }
    }
    
    enum LocationError: LocalizedError {
        case invalidAddress
        case missingLocations
        case routeNotFound
        case insufficientWaypoints
        
        var errorDescription: String? {
            switch self {
            case .invalidAddress:
                return "Invalid address provided"
            case .missingLocations:
                return "Start or end location is missing"
            case .routeNotFound:
                return "Could not find a route between the locations"
            case .insufficientWaypoints:
                return "At least two waypoints are required"
            }
        }
    }
    
    func startTripTracking() {
        isTracking = true
        currentTrip = []
        tripStartTime = Date()
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.showsBackgroundLocationIndicator = true
        locationManager.startUpdatingLocation()
        
        // Start timer to save battery - update every 5 seconds
        tripTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self,
                      let location = self.currentLocation else { return }
                self.currentTrip.append(location)
            }
        }
    }
    
    func stopTripTracking() -> TripData? {
        isTracking = false
        tripEndTime = Date()
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.stopUpdatingLocation()
        tripTimer?.invalidate()
        tripTimer = nil
        
        guard let startTime = tripStartTime,
              let endTime = tripEndTime,
              !currentTrip.isEmpty else {
            return nil
        }
        
        // Calculate trip details
        let tripData = TripData(
            coordinates: currentTrip,
            startTime: startTime,
            endTime: endTime
        )
        
        // Reset tracking data
        currentTrip = []
        tripStartTime = nil
        tripEndTime = nil
        
        return tripData
    }
} 
