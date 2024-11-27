import SwiftUI

struct CarSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var carShareViewModel: CarShareViewModel
    @Binding var selectedCar: Car?
    
    var body: some View {
        NavigationStack {
            List(carShareViewModel.cars) { car in
                Button {
                    selectedCar = car
                    dismiss()
                } label: {
                    HStack {
                        Text(car.name)
                        Spacer()
                        if car.id == selectedCar?.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Select Car")
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