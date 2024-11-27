import SwiftUI

struct CarsView: View {
    @EnvironmentObject private var viewModel: CarShareViewModel
    @State private var showingAddCar = false
    @State private var selectedCar: Car?
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                RefreshableScrollView {
                    LazyVGrid(columns: [GridItem(.flexible())], spacing: 16) {
                        ForEach(viewModel.cars) { car in
                            CarCard(car: car) {
                                selectedCar = car
                            } onTripTap: {
                                // Navigate to trip registration
                                // This is handled by navigationDestination
                            }
                            .contextMenu {
                                Button {
                                    selectedCar = car
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                
                                Button(role: .destructive) {
                                    selectedCar = car
                                    showingDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding()
                } onRefresh: { done in
                    // Simulate a network request delay
                    Task {
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        await MainActor.run {
                            viewModel.loadData()
                            done()
                        }
                    }
                }
            }
            .navigationTitle("Cars")
            .navigationDestination(for: Car.self) { car in
                TripRegistrationView(car: car)
            }
            .toolbar {
                Button {
                    showingAddCar = true
                } label: {
                    Label("Add Car", systemImage: "plus")
                }
            }
            .sheet(isPresented: $showingAddCar) {
                NavigationStack {
                    AddCarView()
                        .interactiveDismissDisabled()
                }
            }
            .sheet(item: $selectedCar, onDismiss: { selectedCar = nil }) { car in
                NavigationStack {
                    EditCarView(car: car)
                        .interactiveDismissDisabled()
                }
            }
            .alert("Delete Car", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let car = selectedCar {
                        withAnimation {
                            viewModel.deleteCar(car)
                        }
                    }
                }
            } message: {
                Text("Are you sure you want to delete this car? All associated trips will also be deleted.")
            }
            
            if viewModel.cars.isEmpty {
                ContentUnavailableView {
                    Label("No Cars", systemImage: "car.2.fill")
                } description: {
                    Text("Add a car to start logging trips")
                }
            }
        }
    }
}

struct CarCard: View {
    let car: Car
    let onEditTap: () -> Void
    let onTripTap: () -> Void
    @EnvironmentObject private var viewModel: CarShareViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Make the card content a NavigationLink
            NavigationLink(value: car) {
                VStack(spacing: 0) {
                    // Car Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(car.name)
                                .font(.title3.bold())
                            Text(car.registrationNumber)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "car.side.fill")
                            .font(.title2)
                            .foregroundStyle(.tint)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    
                    Divider()
                    
                    // Stats
                    let trips = viewModel.getTrips(for: car.id)
                    HStack(spacing: 24) {
                        StatView(
                            title: "Trips",
                            value: "\(trips.count)",
                            icon: "number.circle.fill"
                        )
                        
                        if !trips.isEmpty {
                            let totalDistance = trips.reduce(0) { $0 + $1.distance }
                            StatView(
                                title: "Distance",
                                value: String(format: "%.0f km", totalDistance),
                                icon: "speedometer"
                            )
                            
                            let totalCost = trips.reduce(0) { $0 + $1.cost }
                            StatView(
                                title: "Cost",
                                value: String(format: "%.0f kr", totalCost),
                                icon: "creditcard.fill"
                            )
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                }
            }
            
            // Separate Add Trip button that's also a NavigationLink
            NavigationLink(value: car) {
                Label("Add Trip", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 2)
    }
}

struct StatView: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(.tint)
            
            Text(value)
                .font(.headline)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct EditCarView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: CarShareViewModel
    
    let car: Car
    @State private var name: String
    @State private var registrationNumber: String
    
    init(car: Car) {
        self.car = car
        _name = State(initialValue: car.name)
        _registrationNumber = State(initialValue: car.registrationNumber)
    }
    
    var body: some View {
        Form {
            Section("Car Details") {
                TextField("Car Name", text: $name)
                TextField("Registration Number", text: $registrationNumber)
            }
            
            Section {
                let trips = viewModel.getTrips(for: car.id)
                if !trips.isEmpty {
                    LabeledContent("Total Trips", value: "\(trips.count)")
                    let totalDistance = trips.reduce(0) { $0 + $1.distance }
                    LabeledContent("Total Distance", value: String(format: "%.1f km", totalDistance))
                    let totalCost = trips.reduce(0) { $0 + $1.cost }
                    LabeledContent("Total Cost", value: String(format: "%.2f kr", totalCost))
                } else {
                    Text("No trips registered")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Statistics")
            }
            
            Section {
                Button(role: .destructive) {
                    viewModel.deleteCar(car)
                    dismiss()
                } label: {
                    HStack {
                        Spacer()
                        Text("Delete Car")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Edit Car")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let updatedCar = Car(
                        id: car.id,
                        name: name,
                        registrationNumber: registrationNumber
                    )
                    viewModel.updateCar(updatedCar)
                    dismiss()
                }
                .disabled(name.isEmpty || registrationNumber.isEmpty)
            }
        }
        .onAppear {
            name = car.name
            registrationNumber = car.registrationNumber
        }
    }
} 