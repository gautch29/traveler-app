import SwiftUI

public struct ProfileSettingsView: View {
    @ObservedObject var store: TripStore
    
    @State private var serverURLInput = ""
    @State private var showResetConfirmation = false
    
    public init(store: TripStore) {
        self.store = store
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                Section("Profile Selection") {
                    if let users = store.trip?.users {
                        Picker("Who are you?", selection: Binding(
                            get: { store.selectedUser ?? "" },
                            set: { newValue in
                                store.selectUser(newValue)
                                // Pre-download files for new user
                                Task {
                                    await store.downloadAllFilesForCurrentConfig()
                                }
                            }
                        )) {
                            Text("Select User").tag("")
                            ForEach(users, id: \.self) { user in
                                Text(user).tag(user)
                            }
                        }
                    } else {
                        Text("No profiles available. Sync trip first.")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Server Settings") {
                    TextField("Server Config URL", text: $serverURLInput)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    Button {
                        store.updateServerURL(serverURLInput)
                        Task {
                            await store.sync()
                        }
                    } label: {
                        if store.isSyncing {
                            ProgressView()
                        } else {
                            Text("Save & Sync Trip")
                        }
                    }
                    .disabled(serverURLInput.isEmpty || store.isSyncing)
                    
                    if let error = store.syncError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                if let emergencyInfo = store.trip?.emergencyInfo {
                    Section("Emergency Info 🚨") {
                        ForEach(emergencyInfo.numbers) { num in
                            Button {
                                if let url = URL(string: "tel://\(num.number.replacingOccurrences(of: " ", with: ""))") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                HStack {
                                    Text(num.label)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text(num.number)
                                        .foregroundColor(.accentColor)
                                        .fontWeight(.bold)
                                }
                            }
                        }
                        
                        Text(emergencyInfo.notes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Cache & Local Data") {
                    HStack {
                        Text("Cached Files")
                        Spacer()
                        Text("\(store.downloadedFiles.count) files")
                            .foregroundColor(.secondary)
                    }
                    
                    Button(role: .destructive) {
                        showResetConfirmation = true
                    } label: {
                        Text("Clear Local File Cache")
                    }
                }
            }
            .navigationTitle("Settings & Info ⚙️")
            .onAppear {
                serverURLInput = store.serverURLString
            }
            .confirmationDialog(
                "Are you sure you want to clear the local cache?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear Cache", role: .destructive) {
                    store.clearCache()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will delete all offline PDFs. You will need internet to download them again.")
            }
        }
    }
}
