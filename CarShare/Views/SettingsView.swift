import SwiftUI
import MapKit

struct SettingsView: View {
    @EnvironmentObject var commonLocationsViewModel: CommonLocationsViewModel
    @StateObject private var viewModel = SettingsViewModel()
    @StateObject private var locationSearch = LocationSearchViewModel()
    @State private var showingAddLocation = false
    @State private var newLocationName = ""
    @State private var newLocationAddress = ""
    @State private var showingSearchResults = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(commonLocationsViewModel.locations) { location in
                        LocationRow(location: location)
                    }
                    .onDelete(perform: commonLocationsViewModel.removeLocation)
                    .onMove(perform: commonLocationsViewModel.moveLocation)
                } header: {
                    HStack {
                        Text("Common Locations")
                        Spacer()
                        Button {
                            showingAddLocation = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.blue)
                                .font(.title3)
                                .frame(width: 44, height: 44) // Apple's minimum touch target
                        }
                    }
                } footer: {
                    Text("These locations will appear in the quick selection menu when adding trip locations.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                        .frame(width: 44, height: 44)
                }
            }
        }
        .sheet(isPresented: $showingAddLocation) {
            AddLocationSheet(
                showingSheet: $showingAddLocation,
                locationName: $newLocationName,
                locationAddress: $newLocationAddress,
                locationSearch: locationSearch,
                showingSearchResults: $showingSearchResults,
                onAdd: { name, address in
                    Task {
                        await viewModel.addLocation(name: name, address: address, to: commonLocationsViewModel)
                    }
                }
            )
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("OK") {
                viewModel.error = nil
            }
        } message: {
            if let error = viewModel.error {
                Text(error)
            }
        }
    }
}

// MARK: - Supporting Views

struct LocationRow: View {
    let location: CommonLocation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(location.name)
                .font(.headline)
            Text(location.address)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8) // Increase touch target
    }
}

struct AddLocationSheet: View {
    @Binding var showingSheet: Bool
    @Binding var locationName: String
    @Binding var locationAddress: String
    @ObservedObject var locationSearch: LocationSearchViewModel
    @Binding var showingSearchResults: Bool
    let onAdd: (String, String) -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    Section {
                        TextField("Location Name", text: $locationName)
                            .textContentType(.organizationName)
                            .submitLabel(.next)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Search Address", text: $locationAddress)
                                .textContentType(.fullStreetAddress)
                                .submitLabel(.done)
                                .onChange(of: locationAddress) { _, newValue in
                                    locationSearch.updateSearchText(newValue)
                                    showingSearchResults = !newValue.isEmpty
                                }
                            
                            if showingSearchResults && !locationSearch.searchResults.isEmpty {
                                Divider()
                                
                                ScrollView {
                                    LazyVStack(alignment: .leading, spacing: 0) {
                                        ForEach(locationSearch.searchResults, id: \.self) { result in
                                            SearchResultButton(result: result) {
                                                locationAddress = result.title
                                                showingSearchResults = false
                                                locationSearch.clearResults()
                                            }
                                            
                                            if result != locationSearch.searchResults.last {
                                                Divider()
                                            }
                                        }
                                    }
                                }
                                .frame(maxHeight: 200)
                            }
                        }
                    } footer: {
                        Text("Enter a descriptive name and search for the location address.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                    }
                }
            }
            .navigationTitle("Add Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        locationName = ""
                        locationAddress = ""
                        locationSearch.clearResults()
                        showingSheet = false
                    }
                    .frame(width: 44, height: 44)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(locationName, locationAddress)
                        locationName = ""
                        locationAddress = ""
                        locationSearch.clearResults()
                        showingSheet = false
                    }
                    .disabled(locationName.isEmpty || locationAddress.isEmpty)
                    .frame(width: 44, height: 44)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct SearchResultButton: View {
    let result: MKLocalSearchCompletion
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .foregroundStyle(.primary)
                Text(result.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
    }
} 