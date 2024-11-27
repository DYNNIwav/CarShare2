import Foundation

struct AdditionalCost: Codable, Identifiable {
    let id: UUID
    let description: String
    let amount: Double
    let paidByParticipantId: UUID
}

struct Trip: Identifiable, Codable {
    let id: UUID
    var date: Date
    var distance: Double
    var purpose: String
    var zone: TripZone
    var participantIds: [UUID]
    var additionalCosts: [AdditionalCost]
    var carId: UUID
    
    var cost: Double {
        let distanceCost = distance * zone.ratePerKm
        let additionalCostsSum = additionalCosts.reduce(0) { $0 + $1.amount }
        return distanceCost + additionalCostsSum
    }
    
    var costPerParticipant: Double {
        guard !participantIds.isEmpty else { return 0 }
        return cost / Double(participantIds.count)
    }
    
    init(
        id: UUID = UUID(),
        date: Date,
        distance: Double,
        purpose: String,
        zone: TripZone,
        participantIds: [UUID],
        carId: UUID,
        additionalCosts: [AdditionalCost] = []
    ) {
        self.id = id
        self.date = date
        self.distance = distance
        self.purpose = purpose
        self.zone = zone
        self.participantIds = participantIds
        self.carId = carId
        self.additionalCosts = additionalCosts
    }
} 