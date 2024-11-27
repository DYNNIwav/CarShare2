import SwiftUI
import MapKit

struct TripTrackingView: View {
    @EnvironmentObject var carShareViewModel: CarShareViewModel
    @StateObject private var viewModel: TripTrackingViewModel
    @StateObject private var locationManager = LocationManager()
    
    // Map state
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 59.9139, longitude: 10.7522),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var cameraPosition: MapCameraPosition = .automatic
    
    // UI state
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingBottomSheet = true
    
    init() {
        _viewModel = StateObject(wrappedValue: TripTrackingViewModel(carShareViewModel: CarShareViewModel()))
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Map View
                Map(position: $cameraPosition) {
                    // Current location marker
                    if let location = locationManager.currentLocation {
                        Marker("Current", coordinate: location)
                            .tint(.blue)
                    }
                    
                    // Waypoint markers
                    ForEach(locationManager.waypoints) { waypoint in
                        Marker(waypoint.address, coordinate: waypoint.coordinate)
                            .tint(waypointColor(for: waypoint.type))
                    }
                    
                    // Route segments
                    ForEach(locationManager.routeSegments, id: \.self) { route in
                        MapPolyline(route)
                            .stroke(.blue, lineWidth: 4)
                    }
                }
                .mapStyle(.standard)
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                }
                .ignoresSafeArea()
                
                // Bottom Sheet
                VStack(spacing: 0) {
                    // Handle
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(.secondary)
                        .frame(width: 36, height: 5)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                    
                    if locationManager.isTracking {
                        // Active Trip View
                        VStack(spacing: 20) {
                            // Timer
                            if let startTime = locationManager.tripStartTime {
                                Text(timerString(from: startTime))
                                    .font(.system(.title, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(.primary)
                            }
                            
                            // Distance
                            if locationManager.totalDistance > 0 {
                                Text(String(format: "%.1f km", locationManager.totalDistance / 1000))
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }
                            
                            // Stop Button
                            Button(action: stopTrip) {
                                Label("Stop Trip", systemImage: "stop.circle.fill")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44) // Apple's minimum touch target
                                    .background(.red)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .padding(.top, 8)
                        }
                        .padding()
                    } else {
                        // Trip Setup View
                        VStack(spacing: 16) {
                            // Waypoints List
                            WaypointListView(locationManager: locationManager)
                                .frame(height: 300)
                            
                            // Car Selection
                            Button {
                                viewModel.isShowingCarSelection = true
                            } label: {
                                HStack {
                                    Image(systemName: "car.fill")
                                        .frame(width: 24)
                                    Text(viewModel.selectedCar?.name ?? "Select Car")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                                .foregroundStyle(.primary)
                                .frame(height: 44)
                                .padding(.horizontal)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            
                            // Participants Selection
                            Button {
                                viewModel.isShowingParticipantSelection = true
                            } label: {
                                HStack {
                                    Image(systemName: "person.2.fill")
                                        .frame(width: 24)
                                    Text(viewModel.selectedParticipants.isEmpty ? "Select Participants" : "\(viewModel.selectedParticipants.count) Selected")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                                .foregroundStyle(.primary)
                                .frame(height: 44)
                                .padding(.horizontal)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            
                            // Start Trip Button
                            Button(action: startTrip) {
                                Label("Start Trip", systemImage: "play.circle.fill")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(canStartTrip ? .green : .gray)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(!canStartTrip)
                        }
                        .padding()
                    }
                }
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(radius: 5)
                .frame(maxHeight: showingBottomSheet ? .infinity : 60)
                .padding()
            }
            .navigationTitle("Trip Tracking")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $viewModel.isShowingCarSelection) {
                CarSelectionView(selectedCar: $viewModel.selectedCar)
            }
            .sheet(isPresented: $viewModel.isShowingParticipantSelection) {
                ParticipantSelectionView(selectedParticipants: $viewModel.selectedParticipants)
            }
            .alert("Trip Tracking", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .alert("Error", isPresented: .init(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            )) {
                Button("OK") { viewModel.error = nil }
            } message: {
                if let error = viewModel.error {
                    Text(error)
                }
            }
            .onAppear {
                locationManager.requestAlwaysPermission()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.spring()) {
                            showingBottomSheet.toggle()
                        }
                    } label: {
                        Image(systemName: showingBottomSheet ? "chevron.down" : "chevron.up")
                            .imageScale(.large)
                            .frame(width: 44, height: 44)
                    }
                }
            }
        }
    }
    
    private var canStartTrip: Bool {
        locationManager.waypoints.count >= 2 &&
        viewModel.selectedCar != nil &&
        !viewModel.selectedParticipants.isEmpty
    }
    
    private func startTrip() {
        // Ensure we have at least start and end waypoints
        guard locationManager.waypoints.count >= 2 else {
            alertMessage = "Please add at least a start and end location"
            showingAlert = true
            return
        }
        
        locationManager.startTripTracking()
    }
    
    private func stopTrip() {
        if let tripData = locationManager.stopTripTracking() {
            viewModel.saveTrip(tripData)
            showingAlert = true
            alertMessage = "Trip saved successfully!"
        }
    }
    
    private func timerString(from startTime: Date) -> String {
        let duration = Date().timeIntervalSince(startTime)
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    private func formatDuration(from start: Date, to end: Date) -> String {
        let duration = end.timeIntervalSince(start)
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        return String(format: "%dh %dm", hours, minutes)
    }
    
    private func waypointColor(for type: TripWaypoint.WaypointType) -> Color {
        switch type {
        case .start: return .green
        case .stop: return .blue
        case .end: return .red
        }
    }
} 