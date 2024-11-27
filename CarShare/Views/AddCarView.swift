import SwiftUI

struct AddCarView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: CarShareViewModel
    
    @State private var name = ""
    @State private var registrationNumber = ""
    
    var body: some View {
        Form {
            Section("Car Details") {
                TextField("Car Name", text: $name)
                TextField("Registration Number", text: $registrationNumber)
            }
        }
        .navigationTitle("Add Car")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    let car = Car(
                        name: name,
                        registrationNumber: registrationNumber
                    )
                    viewModel.addCar(car)
                    dismiss()
                }
                .disabled(name.isEmpty || registrationNumber.isEmpty)
            }
        }
    }
} 