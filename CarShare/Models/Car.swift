import Foundation

struct Car: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var registrationNumber: String
    
    init(id: UUID = UUID(), name: String, registrationNumber: String) {
        self.id = id
        self.name = name
        self.registrationNumber = registrationNumber
    }
} 