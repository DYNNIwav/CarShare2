import SwiftUI

struct TripRegistrationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: CarShareViewModel
    
    let car: Car
    @State private var date = Date()
    @State private var distance = ""
    @State private var purpose = ""
    @State private var selectedZone: TripZone = .osloBaerum
    @State private var selectedParticipantIds: Set<UUID> = []
    @State private var additionalCosts: [AdditionalCost] = []
    
    // Additional costs sheet states
    @State private var showingMapDistance = false
    @State private var showingParticipants = false
    @State private var showingZoneSelector = false
    @State private var showingAddCost = false
    @State private var newCostDescription = ""
    @State private var newCostAmount = ""
    @State private var newCostPaidBy: UUID?
    
    var body: some View {
        Form {
            Section {
                DatePicker("Date", selection: $date)
                
                HStack(spacing: 8) {
                    TextField("Distance (km)", text: $distance)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)
                    
                    Button {
                        showingMapDistance = true
                    } label: {
                        Image(systemName: "map.fill")
                            .frame(width: 36, height: 36)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                }
                
                TextField("Purpose", text: $purpose)
            } header: {
                Text("Trip Details")
            }
            
            Section {
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
                
                if !selectedParticipantIds.isEmpty {
                    let participants = viewModel.participants.filter { selectedParticipantIds.contains($0.id) }
                    Button {
                        showingParticipants = true
                    } label: {
                        HStack {
                            Text("Participants")
                            Spacer()
                            Text(participants.map { $0.name }.joined(separator: ", "))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                } else {
                    Button("Add Participants") {
                        showingParticipants = true
                    }
                }
            } header: {
                Text("Trip Settings")
            }
            
            Section {
                ForEach(additionalCosts) { cost in
                    LabeledContent("\(cost.description) (paid by \(viewModel.participants.first(where: { $0.id == cost.paidByParticipantId })?.name ?? "Unknown"))", 
                        value: String(format: "%.2f kr", cost.amount))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .onDelete { indexSet in
                    additionalCosts.remove(atOffsets: indexSet)
                }
                
                Button("Add Cost") {
                    showingAddCost = true
                }
            } header: {
                Text("Additional Costs")
            }
            
            if let distanceValue = Double(distance) {
                Section {
                    LabeledContent("Rate", value: String(format: "%.2f kr/km", selectedZone.ratePerKm))
                    let distanceCost = distanceValue * selectedZone.ratePerKm
                    LabeledContent("Distance Cost", value: String(format: "%.2f kr", distanceCost))
                    
                    if !additionalCosts.isEmpty {
                        Divider()
                        ForEach(additionalCosts) { cost in
                            if viewModel.participants.first(where: { $0.id == cost.paidByParticipantId }) != nil {
                                LabeledContent(cost.description, value: String(format: "%.2f kr", cost.amount))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        let totalExtra = additionalCosts.reduce(0) { $0 + $1.amount }
                        LabeledContent("Total Additional", value: String(format: "%.2f kr", totalExtra))
                            .foregroundStyle(.secondary)
                    }
                    
                    Divider()
                    let totalCost = (distanceValue * selectedZone.ratePerKm) + additionalCosts.reduce(0) { $0 + $1.amount }
                    LabeledContent("Total Cost", value: String(format: "%.2f kr", totalCost))
                        .font(.headline)
                    
                    if !selectedParticipantIds.isEmpty {
                        let costPerPerson = totalCost / Double(selectedParticipantIds.count)
                        LabeledContent("Cost per Person", value: String(format: "%.2f kr", costPerPerson))
                    }
                } header: {
                    Text("Cost Calculation")
                }
            }
        }
        .navigationTitle("Register Trip")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    if let distanceValue = Double(distance), !purpose.isEmpty {
                        let trip = Trip(
                            carId: car.id,
                            date: date,
                            distance: distanceValue,
                            purpose: purpose,
                            zone: selectedZone,
                            participantIds: selectedParticipantIds,
                            additionalCosts: additionalCosts
                        )
                        viewModel.addTrip(trip)
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
            NavigationStack {
                List(TripZone.allCases, id: \.self) { zone in
                    Button {
                        selectedZone = zone
                        showingZoneSelector = false
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
                            showingZoneSelector = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddCost) {
            NavigationStack {
                Form {
                    TextField("Description", text: $newCostDescription)
                    TextField("Amount (kr)", text: $newCostAmount)
                        .keyboardType(.decimalPad)
                    
                    Picker("Paid By", selection: $newCostPaidBy) {
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
                            showingAddCost = false
                        }
                    }
                    
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            if let amount = Double(newCostAmount),
                               !newCostDescription.isEmpty,
                               let paidBy = newCostPaidBy {
                                let newCost = AdditionalCost(
                                    id: UUID(),
                                    description: newCostDescription,
                                    amount: amount,
                                    paidByParticipantId: paidBy
                                )
                                additionalCosts.append(newCost)
                                showingAddCost = false
                                newCostDescription = ""
                                newCostAmount = ""
                                newCostPaidBy = nil
                            }
                        }
                        .disabled(newCostDescription.isEmpty || 
                                newCostAmount.isEmpty || 
                                newCostPaidBy == nil)
                    }
                }
            }
        }
    }
}
