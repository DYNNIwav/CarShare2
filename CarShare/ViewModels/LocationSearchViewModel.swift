import MapKit

@MainActor
class LocationSearchViewModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var searchText = ""
    @Published var searchResults: [MKLocalSearchCompletion] = []
    @Published var isSearching = false
    @Published var isLoading = false
    @Published var error: String?
    
    private var completer: MKLocalSearchCompleter
    private var searchDebounceTimer: Timer?
    
    override init() {
        completer = MKLocalSearchCompleter()
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        
        // Set Norway region bias
        completer.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 59.9139, longitude: 10.7522),
            span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
        )
    }
    
    func updateSearchText(_ text: String) {
        searchText = text
        
        // Cancel any existing timer
        searchDebounceTimer?.invalidate()
        
        if text.isEmpty {
            searchResults = []
            isSearching = false
            isLoading = false
            error = nil
        } else {
            isSearching = true
            isLoading = true
            
            // Use weak self to avoid retain cycles and handle the Sendable requirement
            let weakSelf = self
            searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                Task { @MainActor in
                    weakSelf.completer.queryFragment = text
                }
            }
        }
    }
    
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            searchResults = completer.results
            isSearching = false
            isLoading = false
            error = nil
        }
    }
    
    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.error = error.localizedDescription
            isSearching = false
            isLoading = false
            searchResults = []
        }
    }
} 