import SwiftUI
import Charts

struct StatsCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(.tint)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Text(value)
                .font(.title2.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 2)
    }
}

struct SummaryView: View {
    @EnvironmentObject private var viewModel: CarShareViewModel
    @State private var timeRange: TimeRange = .month
    @State private var expandedParticipants: Set<UUID> = []
    @State private var showingVippsSheet = false
    @State private var selectedSettlement: (from: Participant, to: Participant, amount: Double)?
    
    enum TimeRange: String, CaseIterable {
        case week = "Last 7 Days"
        case month = "Last 30 Days"
        case year = "Last 12 Months"
        case all = "All Time"
        
        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .year: return 365
            case .all: return 3650
            }
        }
    }
    
    private var filteredTrips: [Trip] {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -timeRange.days, to: Date()) ?? Date()
        return viewModel.trips
            .filter { $0.date >= startDate }
            .sorted { $0.date > $1.date }
    }
    
    private var participantStats: [(participant: Participant, stats: ParticipantStats)] {
        viewModel.participants.map { participant in
            let stats = calculateParticipantStats(for: participant)
            return (participant, stats)
        }
        .sorted { $0.stats.totalShare > $1.stats.totalShare }
    }
    
    private func calculateParticipantStats(for participant: Participant) -> ParticipantStats {
        let participantTrips = filteredTrips.filter { $0.participantIds.contains(participant.id) }
        
        let totalDistance = participantTrips.reduce(0) { $0 + $1.distance }
        let tripCount = participantTrips.count
        let tripCosts = participantTrips.reduce(0) { $0 + $1.costPerParticipant() }
        
        let (totalShare, totalPaid) = calculateParticipantCosts(
            participantTrips: participantTrips,
            participantId: participant.id
        )
        
        return ParticipantStats(
            tripCount: tripCount,
            totalDistance: totalDistance,
            totalShare: totalShare,
            totalPaid: totalPaid,
            tripCosts: tripCosts
        )
    }
    
    private func calculateParticipantCosts(participantTrips: [Trip], participantId: UUID) -> (share: Double, paid: Double) {
        var totalShare = 0.0
        var totalPaid = 0.0
        
        // Calculate trip costs (split only among trip participants)
        for trip in participantTrips {
            totalShare += trip.costPerParticipant()
        }
        
        // Calculate additional costs (split among all participants)
        let totalParticipants = Double(viewModel.participants.count)
        for trip in filteredTrips {
            let participantAdditionalCosts = trip.additionalCosts.filter { $0.paidByParticipantId == participantId }
            totalPaid += participantAdditionalCosts.reduce(0) { $0 + $1.amount }
            
            // Add share of all additional costs
            let tripAdditionalCosts = trip.additionalCosts.reduce(0) { $0 + $1.amount }
            totalShare += tripAdditionalCosts / totalParticipants
        }
        
        return (totalShare, totalPaid)
    }
    
    private var totalStats: (distance: Double, tripCosts: Double, additionalCosts: Double, trips: Int) {
        filteredTrips.reduce((0, 0, 0, 0)) { result, trip in
            (
                result.0 + trip.distance,
                result.1 + trip.cost,
                result.2 + trip.additionalCosts.reduce(0) { $0 + $1.amount },
                result.3 + 1
            )
        }
    }
    
    private var settlements: [(from: Participant, to: Participant, amount: Double)] {
        var result: [(from: Participant, to: Participant, amount: Double)] = []
        let stats = participantStats
        
        // Find who owes money (negative balance) and who should receive (positive balance)
        let debtors = stats.filter { $0.stats.balance < 0 }
            .sorted { abs($0.stats.balance) > abs($1.stats.balance) }
        let creditors = stats.filter { $0.stats.balance > 0 }
            .sorted { $0.stats.balance > $1.stats.balance }
        
        var remainingCreditors = creditors
        
        // Match debtors with creditors
        for debtor in debtors {
            var remainingDebt = abs(debtor.stats.balance)
            
            while remainingDebt > 0.01 && !remainingCreditors.isEmpty {
                let creditor = remainingCreditors[0]
                let amount = min(remainingDebt, creditor.stats.balance)
                
                result.append((
                    from: debtor.participant,
                    to: creditor.participant,
                    amount: amount
                ))
                
                remainingDebt -= amount
                
                if creditor.stats.balance - amount < 0.01 {
                    remainingCreditors.removeFirst()
                }
            }
        }
        
        return result
    }
    
    var body: some View {
        NavigationStack {
            RefreshableScrollView {
                VStack(spacing: 20) {
                    // Time Range Picker
                    Picker("Time Range", selection: $timeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Stats Cards
                    LazyVGrid(columns: [.init(), .init()], spacing: 16) {
                        StatsCard(
                            title: "Total Distance",
                            value: String(format: "%.1f km", totalStats.distance),
                            icon: "speedometer"
                        )
                        StatsCard(
                            title: "Total Trips",
                            value: "\(totalStats.trips)",
                            icon: "car.fill"
                        )
                        StatsCard(
                            title: "Trip Costs",
                            value: String(format: "%.0f kr", totalStats.tripCosts),
                            icon: "road.lanes"
                        )
                        StatsCard(
                            title: "Additional Costs",
                            value: String(format: "%.0f kr", totalStats.additionalCosts),
                            icon: "plus.circle.fill"
                        )
                    }
                    .padding(.horizontal)
                    
                    // Settlement Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Settlements")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if settlements.isEmpty {
                            ContentUnavailableView {
                                Label("No Settlements", systemImage: "checkmark.circle.fill")
                            } description: {
                                Text("Everyone is settled up!")
                            }
                            .padding()
                        } else {
                            ForEach(settlements, id: \.from.id) { settlement in
                                SettlementRow(
                                    from: settlement.from,
                                    to: settlement.to,
                                    amount: settlement.amount
                                )
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(radius: 2)
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical)
                    
                    // Participant List
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Participants")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(participantStats, id: \.participant.id) { item in
                            ParticipantRow(
                                participant: item.participant,
                                stats: item.stats,
                                isExpanded: expandedParticipants.contains(item.participant.id)
                            ) {
                                withAnimation {
                                    if expandedParticipants.contains(item.participant.id) {
                                        expandedParticipants.remove(item.participant.id)
                                    } else {
                                        expandedParticipants.insert(item.participant.id)
                                    }
                                }
                            }
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(radius: 2)
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
                .padding(.vertical)
            } onRefresh: { done in
                Task {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    await MainActor.run {
                        viewModel.loadData()
                        done()
                    }
                }
            }
            .navigationTitle("Summary")
            .background(Color(.systemGroupedBackground))
            .sheet(isPresented: $showingVippsSheet) {
                if let settlement = selectedSettlement {
                    VippsPaymentSheet(
                        from: settlement.from,
                        to: settlement.to,
                        amount: settlement.amount
                    )
                }
            }
        }
    }
}

struct ParticipantStats {
    let tripCount: Int
    let totalDistance: Double
    let totalShare: Double
    let totalPaid: Double
    let tripCosts: Double
    
    var balance: Double {
        totalPaid - totalShare
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
            
            Text(value)
                .font(.title3.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 2)
    }
}

struct ChartCard: View {
    let trips: [Trip]
    
    private var monthlyData: [(month: Date, cost: Double)] {
        let calendar = Calendar.current
        var monthlyCosts: [Date: Double] = [:]
        
        for trip in trips {
            let components = calendar.dateComponents([.year, .month], from: trip.date)
            guard let monthStart = calendar.date(from: components) else { continue }
            monthlyCosts[monthStart, default: 0] += trip.cost
        }
        
        return monthlyCosts
            .sorted { $0.key < $1.key }
            .suffix(6)
            .map { ($0.key, $0.value) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Costs")
                .font(.headline)
                .padding(.horizontal)
            
            Chart(monthlyData, id: \.month) { item in
                BarMark(
                    x: .value("Month", item.month, unit: .month),
                    y: .value("Cost", item.cost)
                )
                .foregroundStyle(Color.accentColor.gradient)
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { value in
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 2)
        .padding(.horizontal)
    }
}

struct ParticipantRow: View {
    let participant: Participant
    let stats: ParticipantStats
    let isExpanded: Bool
    let onTap: () -> Void
    @EnvironmentObject private var viewModel: CarShareViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Main row content
            Button(action: onTap) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(participant.name)
                            .font(.headline)
                        Text("\(stats.tripCount) trips • \(String(format: "%.1f km", stats.totalDistance))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(String(format: "%.0f kr", stats.balance))
                            .font(.headline)
                            .foregroundStyle(stats.balance >= 0 ? .green : .red)
                        Text(stats.balance >= 0 ? "to receive" : "to pay")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            
            // Expanded details
            if isExpanded {
                VStack(spacing: 16) {
                    // Trip Costs Breakdown
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Trip Costs")
                            .font(.subheadline.bold())
                        
                        ForEach(viewModel.trips.filter { $0.participantIds.contains(participant.id) }) { trip in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(trip.purpose)
                                        .font(.subheadline)
                                    Text(trip.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(String(format: "%.0f kr", trip.costPerParticipant()))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)
                        }
                        
                        DetailRow(
                            title: "Total Trip Costs",
                            value: String(format: "%.0f kr", stats.tripCosts)
                        )
                        .padding(.horizontal)
                        .padding(.top, 4)
                    }
                    
                    Divider()
                    
                    // Additional Costs Breakdown
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Additional Costs")
                            .font(.subheadline.bold())
                        
                        // Costs paid by this participant
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Paid")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            ForEach(viewModel.trips.flatMap { trip in
                                trip.additionalCosts.filter { $0.paidByParticipantId == participant.id }
                            }) { cost in
                                HStack {
                                    Text(cost.description)
                                        .font(.subheadline)
                                    Spacer()
                                    Text(String(format: "%.0f kr", cost.amount))
                                        .font(.subheadline)
                                        .foregroundStyle(.green)
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        // Share of all additional costs
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Share of Additional Costs")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            ForEach(viewModel.trips.filter { trip in
                                !trip.additionalCosts.isEmpty
                            }) { trip in
                                let totalAdditional = trip.additionalCosts.reduce(0) { $0 + $1.amount }
                                let share = totalAdditional / Double(viewModel.participants.count)
                                
                                HStack {
                                    Text(trip.purpose)
                                        .font(.subheadline)
                                    Spacer()
                                    Text(String(format: "%.0f kr", share))
                                        .font(.subheadline)
                                        .foregroundStyle(.red)
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Summary
                    VStack(spacing: 8) {
                        DetailRow(
                            title: "Total Paid",
                            value: String(format: "%.0f kr", stats.totalPaid)
                        )
                        DetailRow(
                            title: "Total Share",
                            value: String(format: "%.0f kr", stats.totalShare)
                        )
                        DetailRow(
                            title: "Balance",
                            value: String(format: "%.0f kr", stats.balance),
                            valueColor: stats.balance >= 0 ? .green : .red
                        )
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
                .background(Color(.systemGray6))
            }
        }
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    var valueColor: Color = .primary
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(valueColor)
        }
    }
}

struct SettlementRow: View {
    let from: Participant
    let to: Participant
    let amount: Double
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(from.name) owes \(to.name)")
                    .font(.subheadline.bold())
                Text(String(format: "%.0f kr", amount))
                    .font(.title3.bold())
                    .foregroundStyle(.red)
            }
            
            Spacer()
            
            Button {
                if let url = URL(string: "vipps:///?amount=\(Int(amount))") {
                    if UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    } else {
                        if let appStoreURL = URL(string: "https://apps.apple.com/no/app/vipps/id984380185") {
                            UIApplication.shared.open(appStoreURL)
                        }
                    }
                }
            } label: {
                Image("vipps-logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)
                    .background(.white)
                    .clipShape(Circle())
                    .shadow(radius: 1)
            }
        }
        .padding()
    }
}

struct VippsPaymentSheet: View {
    @Environment(\.dismiss) private var dismiss
    let from: Participant
    let to: Participant
    let amount: Double
    @State private var isProcessing = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Payment Details
                VStack(spacing: 16) {
                    Image("vipps-logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 48)
                    
                    VStack(spacing: 8) {
                        Text("Payment to")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(to.name)
                            .font(.title2.bold())
                    }
                    
                    Text(String(format: "%.0f kr", amount))
                        .font(.system(size: 44, weight: .bold))
                }
                .padding(.top)
                
                // Payment Button
                Button {
                    isProcessing = true
                    // Here you would integrate with Vipps API
                    // For now, we'll just simulate a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isProcessing = false
                        dismiss()
                    }
                } label: {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Pay with Vipps")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(red: 0.91, green: 0.17, blue: 0.13))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isProcessing)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Vipps Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isProcessing)
                }
            }
        }
    }
}

struct RefreshableScrollView<Content: View>: View {
    let content: Content
    let onRefresh: (@escaping () -> Void) async -> Void
    
    init(@ViewBuilder content: @escaping () -> Content,
         onRefresh: @escaping (@escaping () -> Void) async -> Void) {
        self.content = content()
        self.onRefresh = onRefresh
    }
    
    var body: some View {
        if #available(iOS 16.0, *) {
            ScrollView {
                content
            }
            .refreshable {
                await onRefresh({})
            }
        } else {
            ScrollView {
                content
            }
        }
    }
} 