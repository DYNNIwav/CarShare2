import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            CarsView()
                .tabItem {
                    Label("Cars", systemImage: "car.fill")
                }
            
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
            
            SummaryView()
                .tabItem {
                    Label("Summary", systemImage: "chart.pie.fill")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
            
            TripTrackingView()
                .tabItem {
                    Label("Track", systemImage: "location.fill")
                }
        }
    }
}

// Only include preview if needed for development
#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(CarShareViewModel())
            .environmentObject(CommonLocationsViewModel())
    }
}
#endif
