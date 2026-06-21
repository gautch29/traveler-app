import SwiftUI
import MapKit
import PassKit
import PDFKit

public struct TimelineView: View {
    @ObservedObject var store: TripStore
    
    public init(store: TripStore) {
        self.store = store
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                // Background USA Map
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 37.0902, longitude: -95.7129),
                    span: MKCoordinateSpan(latitudeDelta: 22, longitudeDelta: 42)
                )))
                .disabled(true)
                .ignoresSafeArea()
                .opacity(0.18)
                .blur(radius: 1.5)
                
                Group {
                    if let trip = store.trip {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                // Trip header
                                tripHeaderView(trip)
                                
                                // Day timeline
                                ForEach(trip.steps) { step in
                                    NavigationLink(value: step) {
                                        TimelineRow(step: step, totalSteps: trip.steps.count)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                
                                Spacer()
                                    .frame(height: 40)
                            }
                        }
                        .scrollContentBackground(.hidden)
                        .refreshable {
                            await store.sync()
                        }
                    } else {
                        emptyStateView
                    }
                }
            }
            .navigationTitle(store.trip?.tripName ?? "My Trip")
            .navigationDestination(for: Step.self) { step in
                StepDetailView(step: step, store: store)
            }
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
        }
    }
    
    // MARK: - Header
    
    private func tripHeaderView(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.tripName)
                        .font(.title)
                        .fontWeight(.bold)
                    Text("\(trip.startDate) to \(trip.endDate) • 3 Weeks")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            // Basic status / info
            if let user = store.selectedUser {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.accentColor)
                    Text("Profile: **\(user)**")
                        .font(.caption)
                    Spacer()
                    Text("Downloaded Files: \(store.downloadedFiles.count)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)
                .padding(.top, 4)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "airplane.circle")
                .font(.system(size: 80))
                .foregroundColor(.secondary)
            
            Text("No Trip Configured")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Go to Settings to enter your server URL and pull the trip configuration. Make sure you run the mock server!")
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

// MARK: - Timeline Row Component

struct TimelineRow: View {
    let step: Step
    let totalSteps: Int
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Timeline connector track
            VStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 14, height: 14)
                    .overlay(
                        Circle()
                            .stroke(Color(.systemBackground), lineWidth: 2)
                    )
                    .padding(.top, 6)
                
                if step.dayNumber < totalSteps {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.3))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                } else {
                    Spacer()
                }
            }
            .frame(width: 40)
            
            // Content Card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("DAY \(step.dayNumber)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.accentColor)
                    
                    Spacer()
                    
                    Text(step.date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(step.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(step.location.name)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Text(step.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 2)
                
                // Show item preview icons
                if !step.items.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(step.items) { item in
                            Image(systemName: item.type.iconName)
                                .font(.caption2)
                                .foregroundColor(.accentColor)
                                .padding(6)
                                .background(Color.accentColor.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding()
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.25),
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
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.6),
                                Color.white.opacity(0.1),
                                Color.clear,
                                Color.white.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
            .padding(.trailing)
            .padding(.bottom, 16)
        }
    }
}

// MARK: - Step Detail View

public struct IdentifiableURL: Identifiable {
    public var id: String { url.absoluteString }
    public let url: URL
}

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

public struct StepDetailView: View {
    let step: Step
    @ObservedObject var store: TripStore
    
    @State private var selectedFileToView: IdentifiableURL? = nil
    @State private var fileViewTitle = ""
    
    public init(step: Step, store: TripStore) {
        self.step = step
        self.store = store
    }
    
    public var body: some View {
        ZStack {
            // Local Map centered on step location coordinates
            Map(initialPosition: .region(MKCoordinateRegion(
                center: step.location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
            )))
            .disabled(true)
            .ignoresSafeArea()
            .opacity(0.25)
            .blur(radius: 1.5)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header card
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("DAY \(step.dayNumber)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.accentColor)
                                .cornerRadius(6)
                            
                            Spacer()
                            
                            Text(step.date)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(step.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        HStack {
                            Text(step.location.name)
                                .font(.body)
                                .foregroundColor(.secondary)
                            
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
                            .padding(.vertical, 8)
                        
                        Text(step.description)
                            .font(.body)
                            .foregroundColor(.primary)
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
                                            Color.white.opacity(0.28),
                                            Color.white.opacity(0.04),
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
                    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
                    .padding(.horizontal)
                    
                    // Activities / Tickets Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Schedule & Bookings")
                            .font(.title3)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        if step.items.isEmpty {
                            Text("No specific schedule details for this day. Free exploration!")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(.thinMaterial)
                                .cornerRadius(12)
                                .padding(.horizontal)
                        } else {
                            ForEach(step.items) { item in
                                activityItemCard(item)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Day \(step.dayNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedFileToView) { identifiableURL in
            if identifiableURL.url.pathExtension.lowercased() == "pkpass" {
                WalletPassView(passURL: identifiableURL.url)
            } else {
                PDFKitView(fileURL: identifiableURL.url, title: fileViewTitle)
            }
        }
    }
    
    // MARK: - Navigation Launcher
    
    private func openInMaps(coordinate: CLLocationCoordinate2D, name: String) {
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = name
        
        let launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
        mapItem.openInMaps(launchOptions: launchOptions)
    }
    
    // MARK: - Activity Card
    
    private func activityItemCard(_ item: TripItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                // Leading Icon
                Image(systemName: item.type.iconName)
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.accentColor)
                    .cornerRadius(10)
                
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
            
            // Files / Tickets attachments
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
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(file.replacingOccurrences(of: "tickets/", with: "").replacingOccurrences(of: "permits/", with: ""))
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                            
                                            Spacer()
                                            
                                            ShareLink(item: url) {
                                                Image(systemName: "square.and.arrow.up")
                                                    .font(.caption)
                                            }
                                        }
                                        
                                        // Inline PDF Integration
                                        PDFKitRepresentable(url: url)
                                            .frame(height: 320)
                                            .cornerRadius(10)
                                            .shadow(color: Color.black.opacity(0.08), radius: 5, x: 0, y: 3)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                                            )
                                    }
                                    .padding(.top, 4)
                                    .padding(.bottom, 8)
                                }
                            } else {
                                Button {
                                    // Trigger file download
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
                        .padding(8)
                        .background(Color(.systemGroupedBackground))
                        .cornerRadius(8)
                    }
                }
            }
            
            // Apple Wallet Passes Section
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
                        .background(Color(.systemGroupedBackground))
                        .cornerRadius(8)
                    }
                }
            }
            
            // Website URL Link
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
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 16)
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
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.55),
                            Color.white.opacity(0.1),
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
        .padding(.horizontal)
    }
}

