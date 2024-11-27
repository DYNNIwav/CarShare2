import SwiftUI
import MapKit

struct TripRegistrationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var carShareViewModel: CarShareViewModel
    @StateObject private var locationManager = LocationManager()
    @State private var purpose = ""
    @State private var selectedZone = TripZone.oslo
    @State private var selectedParticipantIds: Set<UUID> = []
    @State private var selectedCarId: UUID?
    @State private var showingZoneSelector = false
    @State private var showingParticipantSelector = false
    @State private var showingCarSelector = false
    @State private var showingMapDistance = false
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var showingBottomSheet = true
    
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
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            // Waypoints List
                            WaypointListView(locationManager: locationManager)
                                .frame(height: 300)
                            
                            // Trip Details Section
                            VStack(spacing: 16) {
                                TextField("Purpose", text: $purpose)
                                    .textFieldStyle(.roundedBorder)
                                
                                Button {
                                    showingZoneSelector = true
                                } label: {
                                    HStack {
                                        Image(systemName: "map")
                                            .frame(width: 24)
                                        Text("Zone: \(selectedZone.rawValue)")
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                    }
                                    .foregroundStyle(.primary)
                                    .frame(height: 44)
                                    .padding(.horizontal)
                                    .background(.ultraThinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                
                                Button {
                                    showingParticipantSelector = true
                                } label: {
                                    HStack {
                                        Image(systemName: "person.2.fill")
                                            .frame(width: 24)
                                        Text(participantButtonTitle)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                    }
                                    .foregroundStyle(.primary)
                                    .frame(height: 44)
                                    .padding(.horizontal)
                                    .background(.ultraThinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                            .padding(.horizontal)
                            
                            // Total Distance
                            if locationManager.totalDistance > 0 {
                                Text(String(format: "Total Distance: %.1f km", locationManager.totalDistance / 1000))
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }
                            
                            // Register Button
                            Button(action: registerTrip) {
                                Text("Register Trip")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(canRegisterTrip ? .blue : .gray)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(!canRegisterTrip)
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                        }
                    }
                }
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(radius: 5)
                .frame(maxHeight: showingBottomSheet ? .infinity : 60)
                .padding()
            }
            .navigationTitle("Register Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
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
            .sheet(isPresented: $showingZoneSelector) {
                ZoneSelectorView(selectedZone: $selectedZone)
            }
            .sheet(isPresented: $showingParticipantSelector) {
                ParticipantSelectorView(selectedIds: $selectedParticipantIds)
            }
            .sheet(isPresented: $showingCarSelector) {
                CarSelectorView(selectedCarId: $selectedCarId)
            }
            .onAppear {
                locationManager.requestAlwaysPermission()
            }
        }
    }
    
    private var participantButtonTitle: String {
        if selectedParticipantIds.isEmpty {
            return "Select Participants"
        } else {
            return "\(selectedParticipantIds.count) Participants Selected"
        }
    }
    
    private var canRegisterTrip: Bool {
        !purpose.isEmpty &&
        locationManager.waypoints.count >= 2 &&
        !selectedParticipantIds.isEmpty
    }
    
    private func registerTrip() {
        guard let carId = selectedCarId else { return }
        
        // Create trip with current date
        let now = Date()
        
        // Create new Trip
        let trip = Trip(
            date: now,
            distance: locationManager.totalDistance / 1000, // Convert to kilometers
            purpose: purpose,
            zone: selectedZone,
            participantIds: Array(selectedParticipantIds),
            carId: carId,
            additionalCosts: []
        )
        
        // Save trip
        carShareViewModel.addTrip(trip)
        
        dismiss()
    }
    
    private func waypointColor(for type: TripWaypoint.WaypointType) -> Color {
        switch type {
        case .start: return .green
        case .stop: return .blue
        case .end: return .red
        }
    }
}
