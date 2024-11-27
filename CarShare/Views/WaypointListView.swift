import SwiftUI
import MapKit

struct WaypointListView: View {
    @ObservedObject var locationManager: LocationManager
    @StateObject private var locationSearch = LocationSearchViewModel()
    @FocusState private var focusedWaypoint: UUID?
    @State private var editingWaypoint: UUID?
    
    var body: some View {
        List {
            ForEach(locationManager.waypoints) { waypoint in
                WaypointRow(
                    waypoint: waypoint,
                    isEditing: editingWaypoint == waypoint.id,
                    locationSearch: locationSearch,
                    onAddressSelected: { address in
                        Task {
                            if let coordinate = try? await locationManager.geocodeAddress(address) {
                                if let index = locationManager.waypoints.firstIndex(where: { $0.id == waypoint.id }) {
                                    locationManager.waypoints[index].coordinate = coordinate
                                    locationManager.waypoints[index].address = address
                                    try? await locationManager.calculateRouteWithWaypoints()
                                }
                            }
                        }
                        editingWaypoint = nil
                    }
                )
                .focused($focusedWaypoint, equals: waypoint.id)
                .swipeActions(edge: .trailing) {
                    if waypoint.type == .stop {
                        Button(role: .destructive) {
                            withAnimation {
                                locationManager.waypoints.removeAll { $0.id == waypoint.id }
                                Task {
                                    try? await locationManager.calculateRouteWithWaypoints()
                                }
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .onMove { from, to in
                var updatedWaypoints = locationManager.waypoints
                updatedWaypoints.move(fromOffsets: from, toOffset: to)
                
                // Ensure start and end points maintain their positions
                guard let firstIndex = updatedWaypoints.firstIndex(where: { $0.type == .start }),
                      let lastIndex = updatedWaypoints.firstIndex(where: { $0.type == .end }) else {
                    return
                }
                
                if firstIndex != 0 {
                    updatedWaypoints.move(fromOffsets: IndexSet(integer: firstIndex), toOffset: 0)
                }
                if lastIndex != updatedWaypoints.count - 1 {
                    updatedWaypoints.move(fromOffsets: IndexSet(integer: lastIndex), toOffset: updatedWaypoints.count)
                }
                
                locationManager.waypoints = updatedWaypoints
                Task {
                    try? await locationManager.calculateRouteWithWaypoints()
                }
            }
            
            Button {
                withAnimation {
                    let newWaypoint = TripWaypoint(
                        coordinate: locationManager.currentLocation ?? CLLocationCoordinate2D(latitude: 59.9139, longitude: 10.7522),
                        address: "New Stop",
                        type: .stop
                    )
                    // Insert before the end waypoint
                    if let endIndex = locationManager.waypoints.firstIndex(where: { $0.type == .end }) {
                        locationManager.waypoints.insert(newWaypoint, at: endIndex)
                    } else {
                        locationManager.waypoints.append(newWaypoint)
                    }
                    editingWaypoint = newWaypoint.id
                    focusedWaypoint = newWaypoint.id
                }
            } label: {
                Label("Add Stop", systemImage: "plus.circle.fill")
            }
        }
    }
}

struct WaypointRow: View {
    let waypoint: TripWaypoint
    let isEditing: Bool
    @ObservedObject var locationSearch: LocationSearchViewModel
    let onAddressSelected: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: waypointIcon)
                    .foregroundStyle(waypointColor)
                
                if isEditing {
                    TextField("Address", text: .constant(waypoint.address)) { isEditing in
                        if !isEditing {
                            locationSearch.clearResults()
                        }
                    } onCommit: {
                        locationSearch.clearResults()
                    }
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: waypoint.address) { _, newValue in
                        locationSearch.updateSearchText(newValue)
                    }
                } else {
                    Text(waypoint.address)
                        .foregroundStyle(.primary)
                }
            }
            
            if isEditing && !locationSearch.searchResults.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading) {
                        ForEach(locationSearch.searchResults, id: \.self) { result in
                            Button {
                                onAddressSelected(result.title)
                                locationSearch.clearResults()
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(result.title)
                                        .foregroundStyle(.primary)
                                    Text(result.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
    }
    
    private var waypointIcon: String {
        switch waypoint.type {
        case .start: return "location.circle.fill"
        case .stop: return "plus.circle.fill"
        case .end: return "mappin.circle.fill"
        }
    }
    
    private var waypointColor: Color {
        switch waypoint.type {
        case .start: return .green
        case .stop: return .blue
        case .end: return .red
        }
    }
} 