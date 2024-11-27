import SwiftUI
import MapKit

struct MapDistanceView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationManager = LocationManager()
    @StateObject private var startLocationSearch = LocationSearchViewModel()
    @StateObject private var endLocationSearch = LocationSearchViewModel()
    
    @Binding var distance: String
    @State private var startAddress = ""
    @State private var endAddress = ""
    @State private var showingLocationOptions = false
    @State private var isSelectingStartLocation = true
    @State private var cameraPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 59.9139, longitude: 10.7522),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
    )
    
    private let commonLocations = [
        "Oslo Central Station": "Jernbanetorget 1, Oslo",
        "Oslo Airport": "Edvard Munchs veg, Gardermoen",
        "Oslo City Hall": "Rådhusplassen 1, Oslo",
        "University of Oslo": "Problemveien 7, Oslo"
    ]
    
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private var locationStatusMessage: String {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            return "Please grant location access to use your current location"
        case .restricted, .denied:
            return "Location access is denied. Please enable it in Settings"
        case .authorizedWhenInUse, .authorizedAlways:
            return ""
        @unknown default:
            return "Unknown location authorization status"
        }
    }
    
    private func handleAddressSelection(address: String, isStart: Bool) {
        Task {
            do {
                let location = try await locationManager.geocodeAddress(address)
                if isStart {
                    locationManager.startLocation = location
                    startLocationSearch.searchResults = []
                    startAddress = address
                } else {
                    locationManager.endLocation = location
                    endLocationSearch.searchResults = []
                    endAddress = address
                }
                
                if locationManager.startLocation != nil && locationManager.endLocation != nil {
                    try await locationManager.calculateRoute()
                    distance = String(format: "%.1f", locationManager.distance / 1000)
                }
                
                updateMapRegion()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
    
    private func useCurrentLocation(isStart: Bool) {
        Task {
            guard let currentLocation = locationManager.currentLocation else {
                // Show error if location is not available
                return
            }
            
            let location = CLLocation(
                latitude: currentLocation.latitude,
                longitude: currentLocation.longitude
            )
            
            do {
                let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
                if let placemark = placemarks.first,
                   let address = placemark.thoroughfare ?? placemark.name {
                    if isStart {
                        startAddress = address
                        locationManager.startLocation = currentLocation
                    } else {
                        endAddress = address
                        locationManager.endLocation = currentLocation
                    }
                    
                    if locationManager.startLocation != nil && locationManager.endLocation != nil {
                        try await locationManager.calculateRoute()
                        distance = String(format: "%.1f", locationManager.distance / 1000)
                    }
                    
                    updateMapRegion()
                }
            } catch {
                print("Geocoding error: \(error.localizedDescription)")
            }
        }
    }
    
    private func updateMapRegion() {
        if let start = locationManager.startLocation,
           let end = locationManager.endLocation {
            let minLat = min(start.latitude, end.latitude)
            let maxLat = max(start.latitude, end.latitude)
            let minLon = min(start.longitude, end.longitude)
            let maxLon = max(start.longitude, end.longitude)
            
            let center = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            )
            
            let span = MKCoordinateSpan(
                latitudeDelta: (maxLat - minLat) * 1.5,
                longitudeDelta: (maxLon - minLon) * 1.5
            )
            
            withAnimation {
                cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
            }
        }
    }
    
    private func handleSearchResultSelection(result: MKLocalSearchCompletion, isStart: Bool) {
        Task {
            do {
                let searchRequest = MKLocalSearch.Request(completion: result)
                let search = MKLocalSearch(request: searchRequest)
                let response = try await search.start()
                
                guard let coordinate = response.mapItems.first?.placemark.coordinate else {
                    throw LocationManager.LocationError.invalidAddress
                }
                
                if isStart {
                    locationManager.startLocation = coordinate
                    startLocationSearch.searchResults = []
                    startAddress = result.title
                } else {
                    locationManager.endLocation = coordinate
                    endLocationSearch.searchResults = []
                    endAddress = result.title
                }
                
                if locationManager.startLocation != nil && locationManager.endLocation != nil {
                    try await locationManager.calculateRoute()
                    distance = String(format: "%.1f", locationManager.distance / 1000)
                }
                
                updateMapRegion()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Map takes full screen
                Map(position: $cameraPosition) {
                    if let start = locationManager.startLocation {
                        Marker("Start", coordinate: start)
                            .tint(.green)
                    }
                    if let end = locationManager.endLocation {
                        Marker("End", coordinate: end)
                            .tint(.red)
                    }
                    if let route = locationManager.route {
                        MapPolyline(route.polyline)
                            .stroke(.blue, lineWidth: 3)
                    }
                }
                .mapStyle(.standard)
                .ignoresSafeArea()
                .onChange(of: locationManager.route) { _, _ in
                    updateMapRegion()
                }
                
                // Search overlay at the top
                VStack(spacing: 0) {
                    // Search container
                    VStack(spacing: 12) {
                        // Start location
                        HStack(spacing: 12) {
                            Image(systemName: "circle.fill")
                                .foregroundStyle(.green)
                                .frame(width: 44, height: 44)
                            
                            TextField("Start Location", text: $startAddress)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: startAddress) { _, newValue in
                                    startLocationSearch.updateSearchText(newValue)
                                }
                            
                            Menu {
                                if !locationStatusMessage.isEmpty {
                                    Text(locationStatusMessage)
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                } else {
                                    Button {
                                        useCurrentLocation(isStart: true)
                                    } label: {
                                        Label("Current Location", systemImage: "location.fill")
                                    }
                                }
                                
                                Divider()
                                
                                ForEach(Array(commonLocations.keys.sorted()), id: \.self) { name in
                                    Button(name) {
                                        startAddress = commonLocations[name] ?? ""
                                        handleAddressSelection(address: startAddress, isStart: true)
                                    }
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 44, height: 44)
                            }
                        }
                        
                        // End location
                        HStack(spacing: 12) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(.red)
                                .frame(width: 44, height: 44)
                            
                            TextField("End Location", text: $endAddress)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: endAddress) { _, newValue in
                                    endLocationSearch.updateSearchText(newValue)
                                }
                            
                            Menu {
                                if !locationStatusMessage.isEmpty {
                                    Text(locationStatusMessage)
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                } else {
                                    Button {
                                        useCurrentLocation(isStart: false)
                                    } label: {
                                        Label("Current Location", systemImage: "location.fill")
                                    }
                                }
                                
                                Divider()
                                
                                ForEach(Array(commonLocations.keys.sorted()), id: \.self) { name in
                                    Button(name) {
                                        endAddress = commonLocations[name] ?? ""
                                        handleAddressSelection(address: endAddress, isStart: false)
                                    }
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 44, height: 44)
                            }
                        }
                    }
                    .padding(16)
                    .background(.ultraThinMaterial)
                    
                    // Search results
                    if !startLocationSearch.searchResults.isEmpty || !endLocationSearch.searchResults.isEmpty {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                if !startLocationSearch.searchResults.isEmpty {
                                    ForEach(startLocationSearch.searchResults, id: \.self) { result in
                                        Button {
                                            handleSearchResultSelection(result: result, isStart: true)
                                        } label: {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(result.title)
                                                    .foregroundStyle(.primary)
                                                Text(result.subtitle)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        Divider()
                                    }
                                }
                                
                                if !endLocationSearch.searchResults.isEmpty {
                                    ForEach(endLocationSearch.searchResults, id: \.self) { result in
                                        Button {
                                            handleSearchResultSelection(result: result, isStart: false)
                                        } label: {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(result.title)
                                                    .foregroundStyle(.primary)
                                                Text(result.subtitle)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        Divider()
                                    }
                                }
                            }
                        }
                        .background(.ultraThinMaterial)
                        .frame(maxHeight: 300)
                    }
                }
                
                // Distance overlay at the bottom
                if !distance.isEmpty {
                    VStack {
                        Spacer()
                        HStack {
                            Text("\(distance) km")
                                .font(.title2.bold())
                            Spacer()
                            Button("Use Distance") {
                                dismiss()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(16)
                        .background(.ultraThinMaterial)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") {
                showingError = false
            }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            locationManager.requestLocationPermission()
            locationManager.startUpdatingLocation()
        }
        .onDisappear {
            locationManager.stopUpdatingLocation()
        }
    }
} 