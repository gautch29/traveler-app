import SwiftUI
import MapKit

public struct ContentView: View {
    @StateObject private var store = TripStore()
    @State private var onboardingServerURL = ""
    @State private var initialSyncAttempted = false
    
    public init() {}
    
    public var body: some View {
        Group {
            if store.trip == nil || store.selectedUser == nil {
                onboardingView
            } else {
                mainAppTabView
            }
        }
        .onAppear {
            onboardingServerURL = store.serverURLString
            
            // Auto sync on start if URL is set
            Task {
                await store.sync()
            }
        }
    }
    
    // MARK: - Onboarding View (Beautiful Entry)
    
    private var onboardingView: some View {
        ZStack {
            // USA Background Map
            Map(initialPosition: .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.0902, longitude: -95.7129),
                span: MKCoordinateSpan(latitudeDelta: 22, longitudeDelta: 42)
            )))
            .disabled(true)
            .ignoresSafeArea()
            .opacity(0.35)
            .blur(radius: 1.5)
            
            // Elegant background gradient overlay for high contrast
            LinearGradient(
                colors: [Color.accentColor.opacity(0.7), Color(.systemBackground).opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 28) {
                    // App Logo / Icon
                    VStack(spacing: 12) {
                        Image(systemName: "airplane.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                        
                        Text("Traveler")
                            .font(.system(size: 40, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Your Shared USA Adventure Companion")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 40)
                    
                    // Configuration Card
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Connect & Choose Profile")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("1. Enter Server URL")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                            
                            TextField("http://...", text: $onboardingServerURL)
                                .textFieldStyle(.roundedBorder)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .keyboardType(.URL)
                        }
                        
                        Button {
                            store.updateServerURL(onboardingServerURL)
                            Task {
                                await store.sync()
                                initialSyncAttempted = true
                            }
                        } label: {
                            HStack {
                                Spacer()
                                if store.isSyncing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Download Trip Configuration")
                                        .fontWeight(.bold)
                                }
                                Spacer()
                            }
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(onboardingServerURL.isEmpty || store.isSyncing)
                        
                        if let error = store.syncError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }
                        
                        if let trip = store.trip {
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("2. Select Your Profile")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                                
                                ForEach(trip.users, id: \.self) { user in
                                    Button {
                                        store.selectUser(user)
                                        // Trigger final download of PDF files for this profile
                                        Task {
                                            await store.downloadAllFilesForCurrentConfig()
                                        }
                                    } label: {
                                        HStack {
                                            Image(systemName: "person.fill")
                                            Text(user)
                                                .fontWeight(.semibold)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                        }
                                        .padding()
                                        .background(Color.accentColor.opacity(0.1))
                                        .foregroundColor(Color.accentColor)
                                        .cornerRadius(10)
                                    }
                                }
                            }
                        }
                    }
                    .padding(24)
                    .background(Color(.systemBackground))
                    .cornerRadius(24)
                    .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Main Tab View
    
    private var mainAppTabView: some View {
        TabView {
            TimelineView(store: store)
                .tabItem {
                    Label("Timeline", systemImage: "calendar")
                }
            
            if let trip = store.trip {
                MapView(steps: trip.steps)
                    .tabItem {
                        Label("Map", systemImage: "map")
                    }
            }
            
            ExpenseTrackerView(store: store)
                .tabItem {
                    Label("Expenses", systemImage: "dollarsign.circle")
                }
            
            TripEditorView(store: store)
                .tabItem {
                    Label("Editor", systemImage: "pencil.and.outline")
                }
            
            ProfileSettingsView(store: store)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}
