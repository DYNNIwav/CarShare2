import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var viewModel: CarShareViewModel
    @State private var selectedTrip: Trip?
    @State private var showingTripDetail = false
    @State private var searchText = ""
    @State private var selectedTimeFilter: TimeFilter = .all
    @State private var selectedParticipantFilter: UUID?
    @State private var showingFilters = false
    
    private enum TimeFilter: String, CaseIterable {
        case all = "All Time"
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case thisYear = "This Year"
        
        func matches(date: Date) -> Bool {
            let calendar = Calendar.current
            let now = Date()
            switch self {
            case .all:
                return true
            case .thisWeek:
                return calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear)
            case .thisMonth:
                return calendar.isDate(date, equalTo: now, toGranularity: .month)
            case .thisYear:
                return calendar.isDate(date, equalTo: now, toGranularity: .year)
            }
        }
    }
    
    private var filteredCarsWithTrips: [(Car, [Trip])] {
        viewModel.cars.compactMap { car in
            let trips = viewModel.getTrips(for: car.id)
                .filter { trip in
                    let matchesSearch = searchText.isEmpty || 
                        trip.purpose.localizedCaseInsensitiveContains(searchText) ||
                        car.name.localizedCaseInsensitiveContains(searchText) ||
                        car.registrationNumber.localizedCaseInsensitiveContains(searchText)
                    let matchesTimeFilter = selectedTimeFilter.matches(date: trip.date)
                    let matchesParticipant = selectedParticipantFilter.map { trip.participantIds.contains($0) } ?? true
                    return matchesSearch && matchesTimeFilter && matchesParticipant
                }
                .sorted { $0.date > $1.date }
            
            return trips.isEmpty ? nil : (car, trips)
        }
    }
    
    private var totalStats: (distance: Double, cost: Double) {
        filteredCarsWithTrips.reduce((0, 0)) { result, carTrips in
            let tripStats = carTrips.1.reduce((0, 0)) { tripResult, trip in
                let costShare = selectedParticipantFilter != nil ? 
                    trip.cost / Double(trip.participantIds.count) : trip.cost
                return (
                    tripResult.0 + trip.distance,
                    tripResult.1 + costShare
                )
            }
            return (
                result.0 + tripStats.0,
                result.1 + tripStats.1
            )
        }
    }
    
    private var participantFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                FilterChip(
                    isSelected: selectedParticipantFilter == nil,
                    label: "All Trips"
                ) {
                    withAnimation {
                        selectedParticipantFilter = nil
                    }
                }
                
                ForEach(viewModel.participants) { participant in
                    FilterChip(
                        isSelected: selectedParticipantFilter == participant.id,
                        label: participant.name
                    ) {
                        withAnimation {
                            selectedParticipantFilter = participant.id
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Stats Bar
                HStack {
                    Label {
                        Text(String(format: "%.1f km", totalStats.distance))
                            .font(.footnote.weight(.medium))
                    } icon: {
                        Image(systemName: "speedometer")
                            .font(.footnote)
                    }
                    
                    Divider()
                        .frame(height: 12)
                    
                    Label {
                        Text(String(format: "%.2f kr%@", 
                             totalStats.cost,
                             selectedParticipantFilter != nil ? " (your share)" : ""))
                            .font(.footnote.weight(.medium))
                    } icon: {
                        Image(systemName: "creditcard")
                            .font(.footnote)
                    }
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                // Participant Filter Bar
                participantFilterBar
                
                // List with pull-to-refresh
                List {
                    ForEach(filteredCarsWithTrips, id: \.0.id) { car, trips in
                        Section {
                            ForEach(trips) { trip in
                                TripRowView(car: car, trip: trip, selectedParticipantFilter: selectedParticipantFilter)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedTrip = trip
                                        showingTripDetail = true
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            withAnimation {
                                                viewModel.deleteTrip(trip)
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                        
                                        Button {
                                            selectedTrip = trip
                                            showingTripDetail = true
                                        } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }
                                        .tint(.blue)
                                    }
                            }
                        } header: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(car.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(car.registrationNumber)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                // Summary for current filter
                                VStack(alignment: .leading, spacing: 2) {
                                    let totalDistance = trips.reduce(0) { $0 + $1.distance }
                                    Text("Total Distance: \(String(format: "%.1f km", totalDistance))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    let distanceCosts = trips.reduce(0) { $0 + ($1.distance * $1.zone.ratePerKm) }
                                    let additionalCosts = trips.reduce(0) { $0 + $1.additionalCosts.reduce(0) { $0 + $1.amount } }
                                    
                                    if selectedParticipantFilter != nil {
                                        Text("Your Share - Distance: \(String(format: "%.2f kr", distanceCosts / Double(trips[0].participantIds.count)))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text("Your Share - Additional: \(String(format: "%.2f kr", additionalCosts / Double(trips[0].participantIds.count)))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Text("Total Distance Costs: \(String(format: "%.2f kr", distanceCosts))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text("Total Additional Costs: \(String(format: "%.2f kr", additionalCosts))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.top, 4)
                            }
                            .textCase(nil)
                            .padding(.bottom, 8)
                        }
                    }
                }
                .refreshable {
                    // Add pull-to-refresh functionality
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    await MainActor.run {
                        viewModel.loadData()
                    }
                }
            }
            .navigationTitle("Trip History")
            .searchable(text: $searchText, prompt: "Search trips")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Time Period", selection: $selectedTimeFilter) {
                            ForEach(TimeFilter.allCases, id: \.self) { filter in
                                Text(filter.rawValue)
                            }
                        }
                    } label: {
                        Label("Time Filter", systemImage: "calendar")
                            .symbolVariant(selectedTimeFilter != .all ? .fill : .none)
                    }
                }
            }
            .fullScreenCover(item: $selectedTrip) { trip in
                NavigationStack {
                    TripDetailView(trip: trip)
                        .environmentObject(viewModel)
                }
            }
            
            if filteredCarsWithTrips.isEmpty {
                ContentUnavailableView {
                    Label("No Trips Found", systemImage: "car.2.fill")
                } description: {
                    if !searchText.isEmpty {
                        Text("Try adjusting your search term")
                    } else if viewModel.cars.isEmpty {
                        Text("Add a car from the Cars tab to start logging trips")
                    } else {
                        Text("No trips match the current filters")
                    }
                }
            }
        }
    }
}

// Update TripRowView to show additional costs
struct TripRowView: View {
    let car: Car
    let trip: Trip
    let selectedParticipantFilter: UUID?
    @EnvironmentObject private var viewModel: CarShareViewModel
    
    private var participants: [Participant] {
        viewModel.participants.filter { trip.participantIds.contains($0.id) }
    }
    
    private var tripCostShare: Double {
        selectedParticipantFilter != nil ?
            trip.costPerParticipant() :
            trip.cost
    }
    
    private var additionalCostShare: Double {
        let totalAdditional = trip.additionalCosts.reduce(0) { $0 + $1.amount }
        return selectedParticipantFilter != nil ?
            totalAdditional / Double(viewModel.participants.count) :
            totalAdditional
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Date and Distance
            HStack {
                Text(trip.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(String(format: "%.1f km", trip.distance))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            
            // Purpose
            Text(trip.purpose)
                .font(.headline)
            
            // Zone info with costs
            VStack(spacing: 4) {
                HStack {
                    Text(trip.zone.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.2f kr%@", tripCostShare, selectedParticipantFilter != nil ? " (your share)" : ""))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tint)
                }
                
                if !trip.additionalCosts.isEmpty {
                    HStack {
                        Text("Additional Costs")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.2f kr%@", additionalCostShare, selectedParticipantFilter != nil ? " (your share)" : ""))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }
            }
            
            // Participants if any
            if !participants.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(participants) { participant in
                            Text(participant.name)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(selectedParticipantFilter == participant.id ? 
                                    Color.accentColor.opacity(0.2) : .secondary.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// Update TripDetailView to show additional costs
struct TripDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: CarShareViewModel
    let trip: Trip
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false
    
    private var car: Car? {
        viewModel.cars.first { $0.id == trip.carId }
    }
    
    private var participants: [Participant] {
        viewModel.participants.filter { trip.participantIds.contains($0.id) }
    }
    
    var body: some View {
        List {
            // Car Details
            Section("Vehicle") {
                if let car = car {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(car.name)
                            .font(.headline)
                        Text(car.registrationNumber)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Trip Details
            Section("Trip Details") {
                LabeledContent("Date", value: trip.date.formatted(date: .long, time: .shortened))
                LabeledContent("Distance", value: String(format: "%.1f km", trip.distance))
                LabeledContent("Purpose", value: trip.purpose)
                LabeledContent("Zone", value: trip.zone.rawValue)
                
                // Trip Cost
                LabeledContent("Trip Cost", value: String(format: "%.2f kr", trip.cost))
                if !participants.isEmpty {
                    LabeledContent("Trip Cost per Person", value: String(format: "%.2f kr", trip.costPerParticipant()))
                }
            }
            
            // Additional Costs
            if !trip.additionalCosts.isEmpty {
                Section("Additional Costs") {
                    ForEach(trip.additionalCosts) { cost in
                        if let payer = viewModel.participants.first(where: { $0.id == cost.paidByParticipantId }) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(cost.description)
                                    Spacer()
                                    Text(String(format: "%.2f kr", cost.amount))
                                        .foregroundStyle(.secondary)
                                }
                                Text("Paid by \(payer.name)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    let totalAdditional = trip.additionalCosts.reduce(0) { $0 + $1.amount }
                    LabeledContent("Total Additional", value: String(format: "%.2f kr", totalAdditional))
                        .font(.subheadline.bold())
                    
                    if !participants.isEmpty {
                        let sharePerPerson = totalAdditional / Double(viewModel.participants.count)
                        LabeledContent("Share per Person", value: String(format: "%.2f kr", sharePerPerson))
                            .font(.subheadline)
                    }
                }
            }
            
            // Total Cost Summary
            Section("Total Cost Summary") {
                let totalCost = trip.cost + trip.additionalCosts.reduce(0) { $0 + $1.amount }
                LabeledContent("Total Cost", value: String(format: "%.2f kr", totalCost))
                    .font(.headline)
                
                if !participants.isEmpty {
                    let tripShare = trip.costPerParticipant()
                    let additionalShare = trip.additionalCosts.reduce(0) { $0 + $1.amount } / Double(viewModel.participants.count)
                    LabeledContent("Total per Person", value: String(format: "%.2f kr", tripShare + additionalShare))
                        .font(.subheadline.bold())
                }
            }
            
            // Participants
            if !participants.isEmpty {
                Section("Participants") {
                    ForEach(participants) { participant in
                        Text(participant.name)
                    }
                }
            }
            
            // Delete Button
            Section {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    HStack {
                        Spacer()
                        Text("Delete Trip")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Trip Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    showingEditSheet = true
                }
            }
            
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            NavigationStack {
                EditTripView(trip: trip)
                    .environmentObject(viewModel)
            }
        }
        .alert("Delete Trip", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                withAnimation {
                    viewModel.deleteTrip(trip)
                    dismiss()
                }
            }
        } message: {
            Text("Are you sure you want to delete this trip? This action cannot be undone.")
        }
    }
}

// MARK: - FilterChip
struct FilterChip: View {
    let isSelected: Bool
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}