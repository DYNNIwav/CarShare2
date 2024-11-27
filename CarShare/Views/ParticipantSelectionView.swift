import SwiftUI

struct ParticipantSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var carShareViewModel: CarShareViewModel
    @Binding var selectedParticipants: Set<Participant>
    
    var body: some View {
        NavigationStack {
            List(carShareViewModel.participants) { participant in
                Button {
                    if selectedParticipants.contains(participant) {
                        selectedParticipants.remove(participant)
                    } else {
                        selectedParticipants.insert(participant)
                    }
                } label: {
                    HStack {
                        Text(participant.name)
                        Spacer()
                        if selectedParticipants.contains(participant) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Select Participants")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
} 