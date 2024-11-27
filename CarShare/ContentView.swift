import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = CarShareViewModel()
    
    var body: some View {
        TabView {
            CarsView()
                .tabItem {
                    Label("Cars", systemImage: "car.2.fill")
                }
            
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
            
            SummaryView()
                .tabItem {
                    Label("Summary", systemImage: "chart.bar.fill")
                }
        }
        .environmentObject(viewModel)
    }
}

// Only include preview if needed for development
#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
