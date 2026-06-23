import SwiftUI
import MapKit
import PassKit
import PDFKit

public struct TimelineView: View {
    @ObservedObject var store: TripStore
    
    @State private var activeDayIndex = 0
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var initialMapSet = false
    
    @State private var selectedFileToView: IdentifiableURL? = nil
    @State private var fileViewTitle = ""
    
    public init(store: TripStore) {
        self.store = store
    }
    
    public var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // 1. Dynamic Map Background (pans smoothly when activeDayIndex changes)
                Map(position: $mapPosition)
                    .disabled(true)
                    .ignoresSafeArea()
                    .opacity(0.4)
                    .blur(radius: 0.8)
                
                // Dark mode / light mode tint overlay for premium contrast
                Color(.systemBackground)
                    .opacity(0.15)
                    .ignoresSafeArea()
                
                Group {
                    if let trip = store.trip {
                        // TabView with Page style for horizontal "Tinder card" swiping
                        TabView(selection: $activeDayIndex) {
                            ForEach(0..<trip.steps.count, id: \.self) { index in
                                let step = trip.steps[index]
                                
                                ScrollView(showsIndicators: false) {
                                    VStack(spacing: 20) {
                                        // Spacer to let map peak at the top
                                        Spacer()
                                            .frame(height: 20)
                                        
                                        // Primary Floating Glassmorphic Card
                                        daySummaryCard(step)
                                            .padding(.horizontal)
                                        
                                        // Schedule, Bookings & Tickets details
                                        dayDetailsSection(step)
                                            .padding(.horizontal)
                                        
                                        Spacer()
                                            .frame(height: 50)
                                    }
                                }
                                .tag(index)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                    } else {
                        emptyStateView
                    }
                }
            }
            .navigationTitle(store.trip != nil ? "Day \(activeDayIndex + 1)" : "My Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if store.isSyncing {
                        ProgressView()
                    } else {
                        Button {
                            Task {
                                await store.sync()
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .sheet(item: $selectedFileToView) { identifiableURL in
                if identifiableURL.url.pathExtension.lowercased() == "pkpass" {
                    WalletPassView(passURL: identifiableURL.url)
                } else {
                    PDFKitView(fileURL: identifiableURL.url, title: fileViewTitle)
                }
            }
            .onAppear {
                setInitialMapPosition()
            }
            .onChange(of: store.trip) { _ in
                setInitialMapPosition()
            }
            .onChange(of: activeDayIndex) { newIndex in
                updateMapPosition(forIndex: newIndex)
            }
        }
    }
    
    // MARK: - Map Panning Animation
    
    private func setInitialMapPosition() {
        guard let trip = store.trip, !trip.steps.isEmpty, !initialMapSet else { return }
        updateMapPosition(forIndex: activeDayIndex, animated: false)
        initialMapSet = true
    }
    
    private func updateMapPosition(forIndex index: Int, animated: Bool = true) {
        guard let trip = store.trip, index < trip.steps.count else { return }
        let step = trip.steps[index]
        
        let targetRegion = MKCoordinateRegion(
            center: step.location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.22, longitudeDelta: 0.22)
        )
        
        if animated {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.82)) {
                mapPosition = .region(targetRegion)
            }
        } else {
            mapPosition = .region(targetRegion)
        }
    }

    // MARK: - Day Summary Card
    
    private func daySummaryCard(_ step: Step) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("DAY \(step.dayNumber)")
                    .font(.caption2)
                    .fontWeight(.black)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor)
                    .cornerRadius(6)
                
                Spacer()
                
                Text(formatDateString(step.date))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
            }
            
            Text(step.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            HStack {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundColor(.accentColor)
                    .font(.subheadline)
                
                Text(step.location.name)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Spacer()
                
                Button {
                    openInMaps(coordinate: step.location.coordinate, name: step.location.name)
                } label: {
                    Label("Go to", systemImage: "arrow.turn.up.right.circle.fill")
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.accentColor)
            }
            
            Divider()
                .padding(.vertical, 4)
            
            Text(step.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.28),
                                Color.white.opacity(0.03),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.65),
                            Color.white.opacity(0.12),
                            Color.clear,
                            Color.white.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 6)
    }
    
    // MARK: - Day Details Section (Activities, Tickets)
    
    private func dayDetailsSection(_ step: Step) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Schedule & Bookings")
                .font(.headline)
                .fontWeight(.bold)
                .padding(.leading, 4)
            
            if step.items.isEmpty {
                Text("No specific schedule details for this day. Free exploration!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.thinMaterial)
                    )
            } else {
                ForEach(step.items) { item in
                    activityItemCard(item)
                }
            }
        }
    }
    
    // MARK: - Activity Card Component
    
    private func activityItemCard(_ item: TripItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: item.type.iconName)
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.accentColor)
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                        Text(item.time)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.accentColor)
                    }
                    
                    Text(item.details)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // Shared Files and User Specific Files
            let user = store.selectedUser ?? ""
            let applicableFiles = item.getFiles(forUser: user)
            
            if !applicableFiles.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Attachments")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    
                    ForEach(applicableFiles, id: \.self) { file in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "doc.text.fill")
                                    .foregroundColor(.red)
                                
                                Text(file.replacingOccurrences(of: "tickets/", with: "").replacingOccurrences(of: "permits/", with: ""))
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                if store.downloadedFiles.contains(file) {
                                    if let url = store.getLocalFileURL(forFilename: file) {
                                        HStack(spacing: 12) {
                                            ShareLink(item: url) {
                                                Image(systemName: "square.and.arrow.up")
                                                    .font(.caption)
                                            }
                                            
                                            Button {
                                                fileViewTitle = file.components(separatedBy: "/").last ?? "Ticket"
                                                selectedFileToView = IdentifiableURL(url: url)
                                            } label: {
                                                Text("View")
                                                    .font(.caption)
                                                    .bold()
                                            }
                                        }
                                    }
                                } else {
                                    Button {
                                        Task {
                                            if let tripURL = URL(string: store.serverURLString) {
                                                let remoteURL = tripURL.deletingLastPathComponent().appendingPathComponent(file)
                                                try? await store.downloadFile(from: remoteURL, originalFilename: file)
                                            }
                                        }
                                    } label: {
                                        Label("Download PDF", systemImage: "arrow.down.circle")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                            
                            if store.downloadedFiles.contains(file), let url = store.getLocalFileURL(forFilename: file) {
                                PDFKitRepresentable(url: url)
                                    .frame(height: 320)
                                    .cornerRadius(10)
                                    .shadow(color: Color.black.opacity(0.08), radius: 5, x: 0, y: 3)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                                    )
                                    .padding(.top, 4)
                            }
                        }
                        .padding(8)
                        .background(Color(.systemGroupedBackground).opacity(0.5))
                        .cornerRadius(8)
                    }
                }
            }
            
            // Apple Wallet Passes
            let applicablePasses = item.getWalletPasses(forUser: user)
            if !applicablePasses.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Apple Wallet Passes 💳")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    
                    ForEach(applicablePasses, id: \.self) { passFile in
                        HStack {
                            Image(systemName: "wallet.pass.fill")
                                .foregroundColor(.orange)
                            
                            Text(passFile.replacingOccurrences(of: "tickets/", with: "").replacingOccurrences(of: "passes/", with: ""))
                                .font(.caption)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            if store.downloadedFiles.contains(passFile) {
                                HStack(spacing: 8) {
                                    Button {
                                        if let url = store.getLocalFileURL(forFilename: passFile) {
                                            fileViewTitle = passFile.components(separatedBy: "/").last ?? "Pass"
                                            selectedFileToView = IdentifiableURL(url: url)
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "plus.circle")
                                            Text("Add")
                                        }
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 6)
                                        .background(Color.black)
                                        .cornerRadius(6)
                                    }
                                    
                                    Button {
                                        if let walletURL = URL(string: "shoebox://") {
                                            UIApplication.shared.open(walletURL)
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "wallet.pass.fill")
                                            Text("Open")
                                        }
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.primary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 6)
                                        .background(Color(.systemGray5))
                                        .cornerRadius(6)
                                    }
                                }
                            } else {
                                Button {
                                    Task {
                                        if let tripURL = URL(string: store.serverURLString) {
                                            let remoteURL = tripURL.deletingLastPathComponent().appendingPathComponent(passFile)
                                            try? await store.downloadFile(from: remoteURL, originalFilename: passFile)
                                        }
                                    }
                                } label: {
                                    Label("Download", systemImage: "arrow.down.circle")
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(8)
                        .background(Color(.systemGroupedBackground).opacity(0.5))
                        .cornerRadius(8)
                    }
                }
            }
            
            // Website URLs
            if let webString = item.websiteURL, let webURL = URL(string: webString) {
                Divider()
                
                Link(destination: webURL) {
                    HStack {
                        Image(systemName: "safari")
                            .foregroundColor(.accentColor)
                        Text("Open Website")
                            .font(.caption)
                            .bold()
                            .foregroundColor(.accentColor)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                    .padding(10)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.24),
                                Color.white.opacity(0.03),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.55),
                            Color.white.opacity(0.10),
                            Color.clear,
                            Color.white.opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.0
                )
        )
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Navigation Launcher
    
    private func openInMaps(coordinate: CLLocationCoordinate2D, name: String) {
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = name
        let launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
        mapItem.openInMaps(launchOptions: launchOptions)
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "airplane.circle")
                .font(.system(size: 80))
                .foregroundColor(.secondary)
            
            Text("No Trip Configured")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Go to Settings to enter your server URL and pull the trip configuration.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                Task {
                    await store.sync()
                }
            } label: {
                if store.isSyncing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Label("Sync Now", systemImage: "arrow.clockwise")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentColor)
        }
        .padding()
    }
}

// MARK: - Wallet Pass Representable

struct WalletPassView: UIViewControllerRepresentable {
    let passURL: URL
    
    func makeUIViewController(context: Context) -> UIViewController {
        guard let passData = try? Data(contentsOf: passURL),
              let pass = try? PKPass(data: passData) else {
            let vc = UIViewController()
            let label = UILabel()
            label.text = "Failed to load Apple Wallet Pass.\n(Requires valid signed .pkpass signature)"
            label.numberOfLines = 0
            label.textAlignment = .center
            label.textColor = .secondaryLabel
            vc.view.addSubview(label)
            label.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: vc.view.centerYAnchor),
                label.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor, constant: 20),
                label.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor, constant: -20)
            ])
            return vc
        }
        
        guard let addPassVC = PKAddPassesViewController(pass: pass) else {
            let vc = UIViewController()
            let label = UILabel()
            label.text = "Pass already added or is invalid."
            label.textAlignment = .center
            label.textColor = .secondaryLabel
            vc.view.addSubview(label)
            label.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: vc.view.centerYAnchor)
            ])
            return vc
        }
        return addPassVC
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

// MARK: - Date Formatting Helpers

func formatDateString(_ dateStr: String) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    guard let date = formatter.date(from: dateStr) else { return dateStr }
    
    formatter.dateFormat = "MMMM d"
    let basicDate = formatter.string(from: date)
    
    let calendar = Calendar.current
    let day = calendar.component(.day, from: date)
    let suffix: String
    switch day {
    case 1, 21, 31: suffix = "st"
    case 2, 22: suffix = "nd"
    case 3, 23: suffix = "rd"
    default: suffix = "th"
    }
    return "\(basicDate)\(suffix)"
}

func formatDateStringShort(_ dateStr: String) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    guard let date = formatter.date(from: dateStr) else { return dateStr }
    
    formatter.dateFormat = "MMM d"
    return formatter.string(from: date)
}

public struct IdentifiableURL: Identifiable {
    public var id: String { url.absoluteString }
    public let url: URL
}
