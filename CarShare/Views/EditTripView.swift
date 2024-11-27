import SwiftUI

struct EditTripView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: CarShareViewModel
    
    let trip: Trip
    @State private var date: Date
    @State private var distance: String
    @State private var purpose: String
    @State private var selectedZone: TripZone
    @State private var selectedParticipantIds: Set<UUID>
    @State private var additionalCosts: [AdditionalCost]
    
    // Sheet states
    @State private var showingMapDistance = false
    @State private var showingParticipants = false
    @State private var showingZoneSelector = false
    @State private var showingAddCost = false
    
    // Cost form states
    @State private var newCostDescription = ""
    @State private var newCostAmount = ""
    @State private var newCostPaidBy: UUID?
    
    init(trip: Trip) {
        self.trip = trip
        _date = State(initialValue: trip.date)
        _distance = State(initialValue: String(format: "%.1f", trip.distance))
        _purpose = State(initialValue: trip.purpose)
        _selectedZone = State(initialValue: trip.zone)
        _selectedParticipantIds = State(initialValue: Set(trip.participantIds))
        _additionalCosts = State(initialValue: trip.additionalCosts)
    }
    
    var body: some View {
        Form {
            Section("Trip Details") {
                DatePicker("Date", selection: $date)
                
                HStack {
                    TextField("Distance (km)", text: $distance)
                        .keyboardType(.decimalPad)
                    
                    Button {
                        showingMapDistance = true
                    } label: {
                        Image(systemName: "map.fill")
                            .frame(width: 32, height: 32)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                }
                
                TextField("Purpose", text: $purpose)
            }
            
            Section("Trip Settings") {
                Button {
                    showingZoneSelector = true
                } label: {
                    HStack {
                        Text("Zone")
                        Spacer()
                        Text(selectedZone.rawValue)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Button {
                    showingParticipants = true
                } label: {
                    HStack {
                        Text("Participants")
                        Spacer()
                        if !selectedParticipantIds.isEmpty {
                            let participants = viewModel.participants.filter { selectedParticipantIds.contains($0.id) }
                            Text(participants.map { $0.name }.joined(separator: ", "))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        } else {
                            Text("None selected")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            Section("Additional Costs") {
                ForEach(additionalCosts) { cost in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(cost.description)
                            if let payer = viewModel.participants.first(where: { $0.id == cost.paidByParticipantId }) {
                                Text("Paid by \(payer.name)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(String(format: "%.2f kr", cost.amount))
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete { indexSet in
                    additionalCosts.remove(atOffsets: indexSet)
                }
                
                Button("Add Cost") {
                    showingAddCost = true
                }
            }
            
            let distanceValue = Double(distance) ?? 0
            let distanceCost = distanceValue * selectedZone.ratePerKm
            let additionalCostsTotal = additionalCosts.reduce(0) { $0 + $1.amount }
            let totalCost = distanceCost + additionalCostsTotal
            let costPerPerson = selectedParticipantIds.isEmpty ? 0 : totalCost / Double(selectedParticipantIds.count)
            
            Section("Cost Summary") {
                LabeledContent("Distance Cost", value: String(format: "%.2f kr", distanceCost))
                if !additionalCosts.isEmpty {
                    LabeledContent("Additional Costs", value: String(format: "%.2f kr", additionalCostsTotal))
                }
                LabeledContent("Total Cost", value: String(format: "%.2f kr", totalCost))
                if !selectedParticipantIds.isEmpty {
                    LabeledContent("Cost per Person", value: String(format: "%.2f kr", costPerPerson))
                }
            }
        }
        .navigationTitle("Edit Trip")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if let distanceValue = Double(distance), !purpose.isEmpty {
                        let updatedTrip = Trip(
                            id: trip.id,
                            carId: trip.carId,
                            date: date,
                            distance: distanceValue,
                            purpose: purpose,
                            zone: selectedZone,
                            participantIds: Array(selectedParticipantIds),
                            additionalCosts: additionalCosts
                        )
                        viewModel.updateTrip(updatedTrip)
                        dismiss()
                    }
                }
                .disabled(distance.isEmpty || purpose.isEmpty)
            }
        }
        .sheet(isPresented: $showingMapDistance) {
            MapDistanceView(distance: $distance)
        }
        .sheet(isPresented: $showingParticipants) {
            ParticipantsView(selectedParticipantIds: $selectedParticipantIds)
        }
        .sheet(isPresented: $showingZoneSelector) {
            ZoneSelectorView(selectedZone: $selectedZone)
        }
        .sheet(isPresented: $showingAddCost) {
            AddCostView(
                costs: $additionalCosts,
                isPresented: $showingAddCost
            )
        }
        .onAppear {
            date = trip.date
            distance = String(format: "%.1f", trip.distance)
            purpose = trip.purpose
            selectedZone = trip.zone
            selectedParticipantIds = Set(trip.participantIds)
            additionalCosts = trip.additionalCosts
        }
    }
}

// Move ZoneSelector to its own view for clarity
struct ZoneSelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedZone: TripZone
    
    var body: some View {
        NavigationStack {
            List(TripZone.allCases, id: \.self) { zone in
                Button {
                    selectedZone = zone
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(zone.rawValue)
                            Text(String(format: "%.2f kr/km", zone.ratePerKm))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if zone == selectedZone {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }
                .foregroundStyle(.primary)
            }
            .navigationTitle("Select Zone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// Move AddCost to its own view
struct AddCostView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: CarShareViewModel
    @Binding var costs: [AdditionalCost]
    @Binding var isPresented: Bool
    
    @State private var description = ""
    @State private var amount = ""
    @State private var paidBy: UUID?
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Description", text: $description)
                TextField("Amount (kr)", text: $amount)
                    .keyboardType(.decimalPad)
                
                Picker("Paid By", selection: $paidBy) {
                    Text("Select Participant").tag(nil as UUID?)
                    ForEach(viewModel.participants) { participant in
                        Text(participant.name).tag(participant.id as UUID?)
                    }
                }
            }
            .navigationTitle("Add Cost")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let amount = Double(amount),
                           !description.isEmpty,
                           let paidBy = paidBy {
                            let newCost = AdditionalCost(
                                id: UUID(),
                                description: description,
                                amount: amount,
                                paidByParticipantId: paidBy
                            )
                            costs.append(newCost)
                            isPresented = false
                        }
                    }
                    .disabled(description.isEmpty || 
                            amount.isEmpty || 
                            paidBy == nil)
                }
            }
        }
    }
} 