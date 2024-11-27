import SwiftUI

struct ParticipantsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: CarShareViewModel
    @Binding var selectedParticipantIds: Set<UUID>
    
    @State private var showingAddParticipant = false
    @State private var newParticipantName = ""
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.participants) { participant in
                    HStack {
                        Text(participant.name)
                        Spacer()
                        if selectedParticipantIds.contains(participant.id) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selectedParticipantIds.contains(participant.id) {
                            selectedParticipantIds.remove(participant.id)
                        } else {
                            selectedParticipantIds.insert(participant.id)
                        }
                    }
                }
                .onDelete { indexSet in
                    indexSet.forEach { index in
                        let participant = viewModel.participants[index]
                        viewModel.deleteParticipant(participant)
                    }
                }
            }
            .navigationTitle("Participants")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddParticipant = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddParticipant) {
                NavigationStack {
                    Form {
                        TextField("Participant Name", text: $newParticipantName)
                    }
                    .navigationTitle("Add Participant")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                newParticipantName = ""
                                showingAddParticipant = false
                            }
                        }
                        
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Add") {
                                let participant = Participant(name: newParticipantName)
                                viewModel.addParticipant(participant)
                                newParticipantName = ""
                                showingAddParticipant = false
                            }
                            .disabled(newParticipantName.isEmpty)
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }
} 