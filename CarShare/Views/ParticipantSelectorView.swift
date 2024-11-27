import SwiftUI

struct ParticipantSelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var carShareViewModel: CarShareViewModel
    @Binding var selectedIds: Set<UUID>
    
    var body: some View {
        NavigationStack {
            List(carShareViewModel.participants) { participant in
                Button {
                    if selectedIds.contains(participant.id) {
                        selectedIds.remove(participant.id)
                    } else {
                        selectedIds.insert(participant.id)
                    }
                } label: {
                    HStack {
                        Text(participant.name)
                        Spacer()
                        if selectedIds.contains(participant.id) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .foregroundStyle(.primary)
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