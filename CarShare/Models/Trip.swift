import Foundation

struct AdditionalCost: Codable, Identifiable {
    let id: UUID
    let description: String
    let amount: Double
    let paidByParticipantId: UUID
}

struct Trip: Identifiable, Codable {
    let id: UUID
    let carId: UUID
    var date: Date
    var distance: Double
    var purpose: String
    var zone: TripZone
    var participantIds: Set<UUID>
    var additionalCosts: [AdditionalCost]
    
    var cost: Double {
        let distanceCost = distance * zone.ratePerKm
        return distanceCost
    }
    
    func costPerParticipant() -> Double {
        return cost / Double(participantIds.count)
    }
    
    init(id: UUID = UUID(), carId: UUID, date: Date = Date(), distance: Double, purpose: String, zone: TripZone, participantIds: Set<UUID>, additionalCosts: [AdditionalCost] = []) {
        self.id = id
        self.carId = carId
        self.date = date
        self.distance = distance
        self.purpose = purpose
        self.zone = zone
        self.participantIds = participantIds
        self.additionalCosts = additionalCosts
    }
} 