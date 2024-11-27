import SwiftUI
import MapKit

struct MapDistanceView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var commonLocationsViewModel: CommonLocationsViewModel
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
    
    @FocusState private var focusedField: SearchField?
    
    private enum SearchField {
        case start
        case end
    }
    
    private func handleAddressSelection(address: String, isStart: Bool) {
        Task {
            do {
                let location = try await locationManager.geocodeAddress(address)
                
                await MainActor.run {
                    if isStart {
                        startAddress = address
                        locationManager.startLocation = location
                        startLocationSearch.clearResults()
                        focusedField = nil
                    } else {
                        endAddress = address
                        locationManager.endLocation = location
                        endLocationSearch.clearResults()
                        focusedField = nil
                    }
                    
                    if locationManager.startLocation != nil && locationManager.endLocation != nil {
                        Task {
                            try await locationManager.calculateRoute()
                            distance = String(format: "%.1f", locationManager.distance / 1000)
                        }
                    }
                    
                    updateMapRegion()
                }
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
    
    private func useCurrentLocation(isStart: Bool) {
        // First request location permission and start updates
        locationManager.requestLocationPermission()
        locationManager.startUpdatingLocation()
        
        // Create a task to wait for current location
        Task {
            // Wait for up to 5 seconds for location
            for _ in 0..<50 {
                if let currentLocation = locationManager.currentLocation {
                    let location = CLLocation(
                        latitude: currentLocation.latitude,
                        longitude: currentLocation.longitude
                    )
                    
                    do {
                        let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
                        if let placemark = placemarks.first {
                            // Construct a meaningful address string
                            let address = [
                                placemark.thoroughfare,
                                placemark.subThoroughfare,
                                placemark.locality,
                                placemark.postalCode
                            ]
                            .compactMap { $0 }
                            .joined(separator: " ")
                            
                            await MainActor.run {
                                if isStart {
                                    startAddress = address
                                    locationManager.startLocation = currentLocation
                                } else {
                                    endAddress = address
                                    locationManager.endLocation = currentLocation
                                }
                                
                                if locationManager.startLocation != nil && locationManager.endLocation != nil {
                                    Task {
                                        try await locationManager.calculateRoute()
                                        distance = String(format: "%.1f", locationManager.distance / 1000)
                                    }
                                }
                                
                                updateMapRegion()
                            }
                            return
                        }
                    } catch {
                        await MainActor.run {
                            errorMessage = "Failed to get address: \(error.localizedDescription)"
                            showingError = true
                        }
                    }
                }
                try? await Task.sleep(nanoseconds: 100_000_000) // Wait 0.1 seconds before trying again
            }
            
            // If we get here, we timed out waiting for location
            await MainActor.run {
                errorMessage = "Timeout waiting for location. Please try again."
                showingError = true
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
                
                await MainActor.run {
                    if isStart {
                        startAddress = result.title
                        locationManager.startLocation = coordinate
                        startLocationSearch.clearResults()
                        focusedField = nil
                    } else {
                        endAddress = result.title
                        locationManager.endLocation = coordinate
                        endLocationSearch.clearResults()
                        focusedField = nil
                    }
                    
                    if locationManager.startLocation != nil && locationManager.endLocation != nil {
                        Task {
                            try await locationManager.calculateRoute()
                            distance = String(format: "%.1f", locationManager.distance / 1000)
                        }
                    }
                    
                    updateMapRegion()
                }
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
                            
                            let startTextField = TextField("Start Location", text: $startAddress)
                                .textFieldStyle(.roundedBorder)
                                .focused($focusedField, equals: .start)
                            
                            let startTextFieldWithHandlers = startTextField
                                .onChange(of: startAddress) { _, newValue in
                                    startLocationSearch.updateSearchText(newValue)
                                }
                                .onChange(of: focusedField) { _, newValue in
                                    if newValue != .start {
                                        startLocationSearch.clearResults()
                                    }
                                }
                            
                            startTextFieldWithHandlers
                            
                            // Start location menu
                            LocationOptionsMenu(
                                locationStatusMessage: locationStatusMessage,
                                commonLocations: commonLocationsViewModel.locationsDictionary,
                                onCurrentLocation: { useCurrentLocation(isStart: true) },
                                onLocationSelected: { name in
                                    let address = commonLocationsViewModel.locationsDictionary[name] ?? ""
                                    startAddress = address
                                    handleAddressSelection(address: address, isStart: true)
                                }
                            )
                        }
                        
                        // End location
                        HStack(spacing: 12) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(.red)
                                .frame(width: 44, height: 44)
                            
                            let endTextField = TextField("End Location", text: $endAddress)
                                .textFieldStyle(.roundedBorder)
                                .focused($focusedField, equals: .end)
                            
                            let endTextFieldWithHandlers = endTextField
                                .onChange(of: endAddress) { _, newValue in
                                    endLocationSearch.updateSearchText(newValue)
                                }
                                .onChange(of: focusedField) { _, newValue in
                                    if newValue != .end {
                                        endLocationSearch.clearResults()
                                    }
                                }
                            
                            endTextFieldWithHandlers
                            
                            // End location menu
                            LocationOptionsMenu(
                                locationStatusMessage: locationStatusMessage,
                                commonLocations: commonLocationsViewModel.locationsDictionary,
                                onCurrentLocation: { useCurrentLocation(isStart: false) },
                                onLocationSelected: { name in
                                    let address = commonLocationsViewModel.locationsDictionary[name] ?? ""
                                    endAddress = address
                                    handleAddressSelection(address: address, isStart: false)
                                }
                            )
                        }
                    }
                    .padding(16)
                    .background(.ultraThinMaterial)
                    
                    // Search results
                    if !startLocationSearch.searchResults.isEmpty || !endLocationSearch.searchResults.isEmpty {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                if !startLocationSearch.searchResults.isEmpty {
                                    ForEach(startLocationSearch.searchResults, id: \.self) { result in
                                        Button {
                                            handleSearchResultSelection(result: result, isStart: true)
                                        } label: {
                                            SearchResultRow(title: result.title, subtitle: result.subtitle)
                                        }
                                    }
                                }
                                
                                if !endLocationSearch.searchResults.isEmpty {
                                    ForEach(endLocationSearch.searchResults, id: \.self) { result in
                                        Button {
                                            handleSearchResultSelection(result: result, isStart: false)
                                        } label: {
                                            SearchResultRow(title: result.title, subtitle: result.subtitle)
                                        }
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
        }
        .onDisappear {
            locationManager.stopUpdatingLocation()
        }
    }
}

// Extract search result row to a separate view for better performance
struct SearchResultRow: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

struct LocationOptionsMenu: View {
    let locationStatusMessage: String
    let commonLocations: [String: String]
    let onCurrentLocation: () -> Void
    let onLocationSelected: (String) -> Void
    
    var body: some View {
        Menu {
            if !locationStatusMessage.isEmpty {
                Text(locationStatusMessage)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                Button {
                    onCurrentLocation()
                } label: {
                    Label("Current Location", systemImage: "location.fill")
                }
            }
            
            Divider()
            
            ForEach(Array(commonLocations.keys.sorted()), id: \.self) { name in
                Button(name) {
                    onLocationSelected(name)
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

// Update preview if you have one
#if DEBUG
struct MapDistanceView_Previews: PreviewProvider {
    static var previews: some View {
        MapDistanceView(distance: .constant(""))
            .environmentObject(CommonLocationsViewModel())
    }
}
#endif 