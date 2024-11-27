//
//  CarShareApp.swift
//  CarShare
//
//  Created by Pål Omland Eilevstjønn on 26/11/2024.
//

import SwiftUI

@main
struct CarShareApp: App {
    @StateObject private var carShareViewModel = CarShareViewModel()
    @StateObject private var commonLocationsViewModel = CommonLocationsViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(carShareViewModel)
                .environmentObject(commonLocationsViewModel)
        }
    }
}
