import SwiftUI

struct FlightStatusTrackerView: View {
    let flightNumber: String
    let date: String
    @ObservedObject var store: TripStore
    
    @State private var status: FlightStatus? = nil
    @State private var isLoading = false
    @State private var errorOccurred = false
    
    private func isFlightDateNearToday() -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let flightDate = formatter.date(from: date) else { return false }
        
        let diff = Calendar.current.dateComponents([.day], from: Date(), to: flightDate).day ?? 10
        return abs(diff) <= 2
    }
    
    var body: some View {
        VStack {
            if isLoading {
                HStack {
                    ProgressView()
                    Text("Fetching live flight updates...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 6)
                }
                .padding(10)
                .frame(maxWidth: .infinity)
                .liquidGlassStyle(cornerRadius: 12, fillOpacity: 0.015, borderOpacity: 0.25)
            } else if let fs = status {
                HStack(spacing: 12) {
                    Circle()
                        .fill(statusColor(fs.status))
                        .frame(width: 8, height: 8)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Live Flight Status")
                            .font(.caption2)
                            .fontWeight(.black)
                            .foregroundColor(.secondary)
                        Text(fs.status.uppercased())
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    Spacer()
                    
                    if let flightradarURL = URL(string: "https://www.flightradar24.com/data/flights/\(flightNumber.lowercased())") {
                        Link(destination: flightradarURL) {
                            HStack(spacing: 4) {
                                Image(systemName: "safari")
                                Text("FlightRadar24")
                            }
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(8)
                            .foregroundColor(.white)
                            .background(Color.blue)
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(10)
                .liquidGlassStyle(cornerRadius: 12, fillOpacity: 0.015, borderOpacity: 0.25)
            } else {
                // Fallback / Error - Still show FlightRadar24 link
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Flight tracking code: \(flightNumber)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button {
                            loadStatus()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                        }
                    }
                    
                    if let flightradarURL = URL(string: "https://www.flightradar24.com/data/flights/\(flightNumber.lowercased())") {
                        Link(destination: flightradarURL) {
                            HStack {
                                Image(systemName: "safari")
                                Text("Track on FlightRadar24")
                                    .font(.caption)
                                    .bold()
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                            }
                            .padding(8)
                            .foregroundColor(.accentColor)
                            .liquidGlassStyle(cornerRadius: 8, fillOpacity: 0.015, borderOpacity: 0.25)
                        }
                    }
                }
            }
        }
        .task(id: flightNumber) {
            if isFlightDateNearToday() {
                loadStatus()
            }
        }
    }
    
    private func loadStatus() {
        isLoading = true
        errorOccurred = false
        Task {
            if let fetched = await store.fetchFlightStatus(for: flightNumber) {
                self.status = fetched
            } else {
                errorOccurred = true
            }
            isLoading = false
        }
    }
    
    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "on time":
            return .green
        case "delayed":
            return .orange
        case "boarding":
            return .blue
        case "departed", "arrived":
            return .secondary
        default:
            return .red
        }
    }
}
