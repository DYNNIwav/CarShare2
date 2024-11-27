import Foundation
import SwiftUI

@MainActor
class CarShareViewModel: ObservableObject {
    @Published var cars: [Car] = []
    @Published var trips: [Trip] = []
    @Published var participants: [Participant] = []
    
    private let carsKey = "saved_cars"
    private let tripsKey = "saved_trips"
    private let participantsKey = "saved_participants"
    
    private func setupDefaultDataIfNeeded() {
        // Only setup if no data exists
        guard cars.isEmpty && participants.isEmpty else { return }
        
        // Add default cars
        let roy = Car(name: "Roy's Car", registrationNumber: "EL12345")
        let nils = Car(name: "Nils's Car", registrationNumber: "EV67890")
        cars = [roy, nils]
        
        // Add default participants
        let pal = Participant(name: "Pål")
        let johanne = Participant(name: "Johanne")
        let charlotte = Participant(name: "Charlotte")
        let julius = Participant(name: "Julius")
        participants = [pal, johanne, charlotte, julius]
        
        // Save the default data
        saveData()
    }
    
    init() {
        loadData()
        validateDataConsistency()
        setupDefaultDataIfNeeded()
    }
    
    func loadData() {
        do {
            if let carsData = UserDefaults.standard.data(forKey: carsKey) {
                cars = try JSONDecoder().decode([Car].self, from: carsData)
            }
            
            if let tripsData = UserDefaults.standard.data(forKey: tripsKey) {
                trips = try JSONDecoder().decode([Trip].self, from: tripsData)
            }
            
            if let participantsData = UserDefaults.standard.data(forKey: participantsKey) {
                participants = try JSONDecoder().decode([Participant].self, from: participantsData)
            }
            
            validateDataConsistency()
        } catch {
            print("Error loading data: \(error)")
            cars = []
            trips = []
            participants = []
            UserDefaults.standard.removeObject(forKey: carsKey)
            UserDefaults.standard.removeObject(forKey: tripsKey)
            UserDefaults.standard.removeObject(forKey: participantsKey)
        }
    }
    
    private func saveData() {
        do {
            let carsData = try JSONEncoder().encode(cars)
            let tripsData = try JSONEncoder().encode(trips)
            let participantsData = try JSONEncoder().encode(participants)
            
            UserDefaults.standard.set(carsData, forKey: carsKey)
            UserDefaults.standard.set(tripsData, forKey: tripsKey)
            UserDefaults.standard.set(participantsData, forKey: participantsKey)
            UserDefaults.standard.synchronize()
        } catch {
            print("Error saving data: \(error)")
        }
    }
    
    private func validateDataConsistency() {
        trips = trips.filter { trip in
            cars.contains { $0.id == trip.carId }
        }
        
        trips = trips.map { trip in
            var updatedTrip = trip
            updatedTrip.participantIds = trip.participantIds.filter { participantId in
                participants.contains { $0.id == participantId }
            }
            return updatedTrip
        }
        
        saveData()
    }
    
    func addCar(_ car: Car) {
        cars.append(car)
        saveData()
    }
    
    func addTrip(_ trip: Trip) {
        guard cars.contains(where: { $0.id == trip.carId }) else {
            print("Error: Cannot add trip for non-existent car")
            return
        }
        trips.append(trip)
        saveData()
    }
    
    func updateTrip(_ trip: Trip) {
        guard cars.contains(where: { $0.id == trip.carId }) else {
            print("Error: Cannot update trip for non-existent car")
            return
        }
        if let index = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[index] = trip
            saveData()
        }
    }
    
    func deleteTrip(_ tripId: UUID) {
        if let index = trips.firstIndex(where: { $0.id == tripId }) {
            trips.remove(at: index)
            saveTripsToDisk()
        }
    }
    
    func getTrips(for carId: UUID) -> [Trip] {
        trips.filter { $0.carId == carId }
    }
    
    func addParticipant(_ participant: Participant) {
        participants.append(participant)
        saveData()
    }
    
    func deleteParticipant(_ participant: Participant) {
        participants.removeAll { $0.id == participant.id }
        trips = trips.map { trip in
            var updatedTrip = trip
            updatedTrip.participantIds.remove(participant.id)
            return updatedTrip
        }
        saveData()
    }
    
    func updateCar(_ car: Car) {
        if let index = cars.firstIndex(where: { $0.id == car.id }) {
            cars[index] = car
            saveData()
        }
    }
    
    func deleteCar(_ car: Car) {
        // Delete all trips associated with this car
        trips.removeAll { $0.carId == car.id }
        // Delete the car
        cars.removeAll { $0.id == car.id }
        saveData()
    }
} 