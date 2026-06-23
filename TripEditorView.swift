import SwiftUI
import MapKit
import UniformTypeIdentifiers

public struct TripEditorView: View {
    @ObservedObject var store: TripStore
    
    @State private var editedTrip: Trip?
    @State private var showingUploadAlert = false
    @State private var uploadSuccess = false
    @State private var uploadMessage = ""
    @State private var isUploading = false
    
    public init(store: TripStore) {
        self.store = store
    }
    
    public var body: some View {
        NavigationStack {
            Group {
                if let trip = editedTrip {
                    Form {
                        Section("Trip Settings") {
                            TextField("Trip Name", text: Binding(
                                get: { trip.tripName },
                                set: { editedTrip = Trip(tripName: $0, startDate: trip.startDate, endDate: trip.endDate, users: trip.users, emergencyInfo: trip.emergencyInfo, steps: trip.steps) }
                            ))
                            TextField("Start Date (YYYY-MM-DD)", text: Binding(
                                get: { trip.startDate },
                                set: { editedTrip = Trip(tripName: trip.tripName, startDate: $0, endDate: trip.endDate, users: trip.users, emergencyInfo: trip.emergencyInfo, steps: trip.steps) }
                            ))
                            TextField("End Date (YYYY-MM-DD)", text: Binding(
                                get: { trip.endDate },
                                set: { editedTrip = Trip(tripName: trip.tripName, startDate: trip.startDate, endDate: $0, users: trip.users, emergencyInfo: trip.emergencyInfo, steps: trip.steps) }
                            ))
                        }
                        
                        Section("Users / Profiles") {
                            Text(trip.users.joined(separator: ", "))
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        }
                        
                        Section("Days / Steps") {
                            List {
                                ForEach(trip.steps) { step in
                                    NavigationLink(destination: DayEditorView(step: step, users: trip.users, store: store, onSave: { updatedStep in
                                        updateStep(updatedStep)
                                    })) {
                                        HStack {
                                            Text("Day \(step.dayNumber)")
                                                .fontWeight(.bold)
                                                .foregroundColor(.accentColor)
                                            Text(step.title)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                                .onDelete(perform: deleteStep)
                            }
                            
                            Button(action: addStep) {
                                Label("Add Day", systemImage: "calendar.badge.plus")
                            }
                        }
                        
                        Section("Save Changes") {
                            Button(action: saveAndUpload) {
                                if isUploading {
                                    HStack {
                                        ProgressView()
                                        Text("Uploading to Server...")
                                            .padding(.leading, 8)
                                    }
                                } else {
                                    Label("Upload Trip to Server ☁️", systemImage: "icloud.and.arrow.up.fill")
                                }
                            }
                            .disabled(isUploading)
                            .frame(maxWidth: .infinity)
                            .alignmentGuide(.leading) { _ in 0 }
                        }
                    }
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "square.and.pencil.circle")
                            .font(.system(size: 80))
                            .foregroundColor(.secondary)
                        Text("No Trip Config Loaded")
                            .font(.headline)
                        Button("Load Current Config") {
                            editedTrip = store.trip
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
            .navigationTitle("Itinerary Editor ✍️")
            .onAppear {
                if editedTrip == nil {
                    editedTrip = store.trip
                }
            }
            .alert(uploadSuccess ? "Upload Succeeded" : "Upload Failed", isPresented: $showingUploadAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(uploadMessage)
            }
        }
    }
    
    // MARK: - Editor Operations
    
    private func updateStep(_ updatedStep: Step) {
        guard let trip = editedTrip else { return }
        var updatedSteps = trip.steps
        if let idx = updatedSteps.firstIndex(where: { $0.id == updatedStep.id }) {
            updatedSteps[idx] = updatedStep
        }
        
        // Resort steps by dayNumber just in case
        updatedSteps.sort(by: { $0.dayNumber < $1.dayNumber })
        
        editedTrip = Trip(tripName: trip.tripName, startDate: trip.startDate, endDate: trip.endDate, users: trip.users, emergencyInfo: trip.emergencyInfo, steps: updatedSteps)
    }
    
    private func addStep() {
        guard let trip = editedTrip else { return }
        let nextDayNum = (trip.steps.map { $0.dayNumber }.max() ?? 0) + 1
        
        let newStep = Step(
            id: UUID().uuidString.lowercased(),
            dayNumber: nextDayNum,
            title: "New Day Step",
            date: "2026-08-\(String(format: "%02d", nextDayNum))",
            location: LocationInfo(name: "New Destination", latitude: 37.0902, longitude: -95.7129),
            description: "Describe the day activities here.",
            items: []
        )
        
        let updatedSteps = (trip.steps + [newStep]).sorted(by: { $0.dayNumber < $1.dayNumber })
        editedTrip = Trip(tripName: trip.tripName, startDate: trip.startDate, endDate: trip.endDate, users: trip.users, emergencyInfo: trip.emergencyInfo, steps: updatedSteps)
    }
    
    private func deleteStep(at offsets: IndexSet) {
        guard let trip = editedTrip else { return }
        var updatedSteps = trip.steps
        updatedSteps.remove(atOffsets: offsets)
        
        // Re-index day numbers sequentially
        for i in 0..<updatedSteps.count {
            let step = updatedSteps[i]
            updatedSteps[i] = Step(id: step.id, dayNumber: i + 1, title: step.title, date: step.date, location: step.location, description: step.description, items: step.items)
        }
        
        editedTrip = Trip(tripName: trip.tripName, startDate: trip.startDate, endDate: trip.endDate, users: trip.users, emergencyInfo: trip.emergencyInfo, steps: updatedSteps)
    }
    
    private func saveAndUpload() {
        guard let trip = editedTrip else { return }
        isUploading = true
        
        Task {
            // 1. Update the store's copy locally
            store.trip = trip
            
            // 2. Upload to server
            let success = await store.uploadTrip()
            
            isUploading = false
            uploadSuccess = success
            if success {
                uploadMessage = "The updated itinerary has been successfully saved to the server and synchronized!"
                
                // Re-download assets based on newly modified config
                await store.downloadAllFilesForCurrentConfig()
            } else {
                uploadMessage = "Failed to upload to the server. Please verify the mock server is running and the connection URL is correct."
            }
            showingUploadAlert = true
        }
    }
}

// MARK: - Day Editor View

struct DayEditorView: View {
    @State var step: Step
    let users: [String]
    let store: TripStore
    let onSave: (Step) -> Void
    
    @State private var locName = ""
    @State private var locLat = ""
    @State private var locLng = ""
    
    @State private var isGenerating = false
    @State private var isAnimating = false
    
    var body: some View {
        Form {
            Section("Day Properties") {
                TextField("Step Title", text: $step.title)
                TextField("Date", text: $step.date)
                TextField("Description", text: $step.description, axis: .vertical)
                    .lineLimit(3...6)
                
                Button(action: generateDetail) {
                    HStack(spacing: 8) {
                        if isGenerating {
                            ProgressView()
                                .tint(.white)
                            Text("Generating Summary...")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Generate Day Detail")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.6, green: 0.3, blue: 0.9), // Purple
                                Color(red: 0.95, green: 0.3, blue: 0.6), // Pink
                                Color(red: 0.3, green: 0.6, blue: 0.9)  // Blue
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(10)
                    .shadow(color: Color.purple.opacity(isGenerating ? 0.5 : 0.2), radius: isGenerating ? 6 : 3)
                    .scaleEffect(isGenerating && isAnimating ? 0.98 : 1.0)
                    .opacity(isGenerating && isAnimating ? 0.8 : 1.0)
                }
                .buttonStyle(.plain)
                .disabled(isGenerating)
                .padding(.vertical, 4)
            }
            
            Section("Location (Map integration)") {
                TextField("Location Name", text: $locName)
                TextField("Latitude", text: $locLat)
                    .keyboardType(.decimalPad)
                TextField("Longitude", text: $locLng)
                    .keyboardType(.decimalPad)
            }
            
            Section("Schedule & Activities") {
                List {
                    ForEach(step.items) { item in
                        NavigationLink(destination: ActivityEditorView(item: item, users: users, store: store, onSave: { updatedItem in
                            updateItem(updatedItem)
                        })) {
                            HStack {
                                Image(systemName: item.type.iconName)
                                    .foregroundColor(.accentColor)
                                VStack(alignment: .leading) {
                                    Text(item.title)
                                        .font(.subheadline)
                                    Text(item.time)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteItem)
                }
                
                Button(action: addItem) {
                    Label("Add Activity", systemImage: "plus.circle")
                }
            }
        }
        .navigationTitle("Day \(step.dayNumber) Editor")
        .onAppear {
            locName = step.location.name
            locLat = String(step.location.latitude)
            locLng = String(step.location.longitude)
        }
        .onDisappear {
            // Save location parameters
            let lat = Double(locLat) ?? 37.0902
            let lng = Double(locLng) ?? -95.7129
            let updatedStep = Step(
                id: step.id,
                dayNumber: step.dayNumber,
                title: step.title,
                date: step.date,
                location: LocationInfo(name: locName, latitude: lat, longitude: lng),
                description: step.description,
                items: step.items
            )
            onSave(updatedStep)
        }
    }
    
    private func updateItem(_ updatedItem: TripItem) {
        var items = step.items
        if let idx = items.firstIndex(where: { $0.id == updatedItem.id }) {
            items[idx] = updatedItem
        }
        step = Step(id: step.id, dayNumber: step.dayNumber, title: step.title, date: step.date, location: step.location, description: step.description, items: items)
    }
    
    private func addItem() {
        let newItem = TripItem(
            id: UUID().uuidString.lowercased(),
            type: .activity,
            title: "New Activity",
            time: "12:00 PM",
            details: "Activity Details",
            sharedFiles: [],
            profileFiles: [:],
            walletPasses: [],
            profileWalletPasses: [:],
            websiteURL: nil,
            flightNumber: nil
        )
        let items = step.items + [newItem]
        step = Step(id: step.id, dayNumber: step.dayNumber, title: step.title, date: step.date, location: step.location, description: step.description, items: items)
    }
    
    private func deleteItem(at offsets: IndexSet) {
        var items = step.items
        items.remove(atOffsets: offsets)
        step = Step(id: step.id, dayNumber: step.dayNumber, title: step.title, date: step.date, location: step.location, description: step.description, items: items)
    }
    
    private func generateDetail() {
        isGenerating = true
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            isAnimating = true
        }
        
        Task {
            if let summary = await store.generateAISummary(title: step.title, locationName: locName, items: step.items) {
                await MainActor.run {
                    step.description = summary
                }
            }
            await MainActor.run {
                withAnimation {
                    isGenerating = false
                    isAnimating = false
                }
            }
        }
    }
}

// MARK: - Activity Editor View

struct ActivityEditorView: View {
    enum UploadTarget: Equatable {
        case sharedPDF
        case profilePDF(user: String)
        case sharedPass
        case profilePass(user: String)
    }

    @State var item: TripItem
    let users: [String]
    let store: TripStore
    let onSave: (TripItem) -> Void
    
    @State private var typeIndex = 0
    @State private var sharedFilesInput = ""
    @State private var sharedPassesInput = ""
    @State private var websiteURLInput = ""
    @State private var flightNumberInput = ""
    
    // Manage profile mappings
    @State private var profileFiles = [String: String]()
    @State private var profilePasses = [String: String]()
    
    // Upload state
    @State private var showingFilePicker = false
    @State private var uploadingTarget: UploadTarget? = nil
    @State private var isUploadingFile = false
    @State private var uploadErrorMsg = ""
    @State private var showingUploadError = false
    
    var body: some View {
        Form {
            Section("Properties") {
                TextField("Activity Title", text: $item.title)
                TextField("Time", text: $item.time)
                TextField("Details", text: $item.details, axis: .vertical)
                
                Picker("Activity Type", selection: $typeIndex) {
                    ForEach(0..<TripItemType.allCases.count, id: \.self) { idx in
                        Text(TripItemType.allCases[idx].rawValue.capitalized).tag(idx)
                    }
                }
            }
            
            if TripItemType.allCases[typeIndex] == .flight {
                Section("Flight Status Tracking") {
                    TextField("Flight Number (e.g. AF372)", text: $flightNumberInput)
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)
                }
            }
            
            Section("Links") {
                TextField("Website URL", text: $websiteURLInput)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
            }
            
            Section("PDF Ticket Files") {
                HStack {
                    TextField("Shared PDFs (e.g. tickets/hotel.pdf)", text: $sharedFilesInput)
                        .autocapitalization(.none)
                    
                    Button {
                        uploadingTarget = .sharedPDF
                        showingFilePicker = true
                    } label: {
                        Image(systemName: "icloud.and.arrow.up")
                    }
                }
                
                Text("Personal PDFs (per User):")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ForEach(users, id: \.self) { user in
                    HStack {
                        Text(user)
                            .frame(width: 80, alignment: .leading)
                        TextField("tickets/ticket.pdf", text: Binding(
                            get: { profileFiles[user] ?? "" },
                            set: { newValue in
                                if newValue.isEmpty {
                                    profileFiles.removeValue(forKey: user)
                                } else {
                                    profileFiles[user] = newValue
                                }
                            }
                        ))
                        .autocapitalization(.none)
                        
                        Button {
                            uploadingTarget = .profilePDF(user: user)
                            showingFilePicker = true
                        } label: {
                            Image(systemName: "icloud.and.arrow.up")
                        }
                    }
                }
            }
            
            Section("Apple Wallet Passes") {
                HStack {
                    TextField("Shared Passes (e.g. passes/ticket.pkpass)", text: $sharedPassesInput)
                        .autocapitalization(.none)
                    
                    Button {
                        uploadingTarget = .sharedPass
                        showingFilePicker = true
                    } label: {
                        Image(systemName: "icloud.and.arrow.up")
                    }
                }
                
                Text("Personal Passes (per User):")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ForEach(users, id: \.self) { user in
                    HStack {
                        Text(user)
                            .frame(width: 80, alignment: .leading)
                        TextField("passes/pass.pkpass", text: Binding(
                            get: { profilePasses[user] ?? "" },
                            set: { newValue in
                                if newValue.isEmpty {
                                    profilePasses.removeValue(forKey: user)
                                } else {
                                    profilePasses[user] = newValue
                                }
                            }
                        ))
                        .autocapitalization(.none)
                        
                        Button {
                            uploadingTarget = .profilePass(user: user)
                            showingFilePicker = true
                        } label: {
                            Image(systemName: "icloud.and.arrow.up")
                        }
                    }
                }
            }
            
            if isUploadingFile {
                Section {
                    HStack {
                        ProgressView()
                        Text("Uploading file to server...")
                            .padding(.leading, 8)
                    }
                }
            }
        }
        .navigationTitle("Activity Editor")
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.pdf, .data],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result: result)
        }
        .alert("Upload Failed", isPresented: $showingUploadError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(uploadErrorMsg)
        }
        .onAppear {
            if let idx = TripItemType.allCases.firstIndex(of: item.type) {
                typeIndex = idx
            }
            sharedFilesInput = item.sharedFiles.joined(separator: ", ")
            sharedPassesInput = (item.walletPasses ?? []).joined(separator: ", ")
            websiteURLInput = item.websiteURL ?? ""
            flightNumberInput = item.flightNumber ?? ""
            
            // Populate profile dictionaries
            for user in users {
                profileFiles[user] = item.profileFiles?[user] ?? ""
                profilePasses[user] = item.profileWalletPasses?[user] ?? ""
            }
        }
        .onDisappear {
            // Save state back with normalization to ensure proper parent directories exist
            let sharedFiles = sharedFilesInput.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .map { file -> String in
                    if !file.contains("/") {
                        return "tickets/\(file)"
                    }
                    return file
                }
                
            let walletPasses = sharedPassesInput.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .map { pass -> String in
                    if !pass.contains("/") {
                        return "passes/\(pass)"
                    }
                    return pass
                }
            
            var pFiles = [String: String]()
            var pPasses = [String: String]()
            
            for user in users {
                if let file = profileFiles[user], !file.isEmpty {
                    let trimmed = file.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.contains("/") {
                        pFiles[user] = "tickets/\(trimmed)"
                    } else {
                        pFiles[user] = trimmed
                    }
                }
                if let pass = profilePasses[user], !pass.isEmpty {
                    let trimmed = pass.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.contains("/") {
                        pPasses[user] = "passes/\(trimmed)"
                    } else {
                        pPasses[user] = trimmed
                    }
                }
            }
            
            let flightNum = flightNumberInput.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let updatedItem = TripItem(
                id: item.id,
                type: TripItemType.allCases[typeIndex],
                title: item.title,
                time: item.time,
                details: item.details,
                sharedFiles: sharedFiles,
                profileFiles: pFiles.isEmpty ? nil : pFiles,
                walletPasses: walletPasses.isEmpty ? nil : walletPasses,
                profileWalletPasses: pPasses.isEmpty ? nil : pPasses,
                websiteURL: websiteURLInput.isEmpty ? nil : websiteURLInput,
                flightNumber: flightNum.isEmpty ? nil : flightNum
            )
            onSave(updatedItem)
        }
    }
    
    private func handleFileImport(result: Result<[URL], Error>) {
        guard let target = uploadingTarget else { return }
        
        switch result {
        case .success(let urls):
            guard let selectedURL = urls.first else { return }
            
            let gotAccess = selectedURL.startAccessingSecurityScopedResource()
            defer {
                if gotAccess {
                    selectedURL.stopAccessingSecurityScopedResource()
                }
            }
            
            do {
                let fileData = try Data(contentsOf: selectedURL)
                let rawFilename = selectedURL.lastPathComponent
                
                // Determine prefix folder
                let folder: String
                switch target {
                case .sharedPDF, .profilePDF:
                    folder = "tickets"
                case .sharedPass, .profilePass:
                    folder = "passes"
                }
                
                let serverPath = "\(folder)/\(rawFilename)"
                
                isUploadingFile = true
                Task {
                    let success = await store.uploadFile(data: fileData, filename: serverPath)
                    isUploadingFile = false
                    
                    if success {
                        // Automatically fill the fields
                        switch target {
                        case .sharedPDF:
                            if sharedFilesInput.isEmpty {
                                sharedFilesInput = serverPath
                            } else {
                                sharedFilesInput += ", \(serverPath)"
                            }
                        case .profilePDF(let user):
                            profileFiles[user] = serverPath
                        case .sharedPass:
                            if sharedPassesInput.isEmpty {
                                sharedPassesInput = serverPath
                            } else {
                                sharedPassesInput += ", \(serverPath)"
                            }
                        case .profilePass(let user):
                            profilePasses[user] = serverPath
                        }
                    } else {
                        uploadErrorMsg = "Failed to upload file to the server."
                        showingUploadError = true
                    }
                }
            } catch {
                uploadErrorMsg = "Error reading local file: \(error.localizedDescription)"
                showingUploadError = true
            }
        case .failure(let error):
            uploadErrorMsg = "Error picking file: \(error.localizedDescription)"
            showingUploadError = true
        }
    }
}
