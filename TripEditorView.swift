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
    
    @State private var mapPosition: MapCameraPosition = .automatic
    
    public init(store: TripStore) {
        self.store = store
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                // Background Map
                Map(position: $mapPosition)
                    .disabled(true)
                    .ignoresSafeArea()
                    .opacity(0.3)
                    .blur(radius: 1.0)
                
                Color(.systemBackground)
                    .opacity(0.2)
                    .ignoresSafeArea()
                
                if let trip = editedTrip {
                    List {
                        tripSettingsSection(trip: trip)
                        usersSection(trip: trip)
                        stepsSection(trip: trip)
                        saveChangesSection()
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
            .onAppear {
                if editedTrip == nil {
                    editedTrip = store.trip
                }
                setInitialMapPosition()
            }
            .alert(uploadSuccess ? "Upload Succeeded" : "Upload Failed", isPresented: $showingUploadAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(uploadMessage)
            }
        }
    }
    
    // MARK: - Subviews
    
    private func tripSettingsSection(trip: Trip) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("Trip Name")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                TextField("Trip Name", text: Binding(
                    get: { trip.tripName },
                    set: { editedTrip = Trip(tripName: $0, startDate: trip.startDate, endDate: trip.endDate, users: trip.users, emergencyInfo: trip.emergencyInfo, steps: trip.steps) }
                ))
                .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Start Date")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                TextField("Start Date (YYYY-MM-DD)", text: Binding(
                    get: { trip.startDate },
                    set: { editedTrip = Trip(tripName: trip.tripName, startDate: $0, endDate: trip.endDate, users: trip.users, emergencyInfo: trip.emergencyInfo, steps: trip.steps) }
                ))
                .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("End Date")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                TextField("End Date (YYYY-MM-DD)", text: Binding(
                    get: { trip.endDate },
                    set: { editedTrip = Trip(tripName: trip.tripName, startDate: trip.startDate, endDate: $0, users: trip.users, emergencyInfo: trip.emergencyInfo, steps: trip.steps) }
                ))
                .textFieldStyle(.roundedBorder)
            }
        } header: {
            Text("Trip Settings")
                .foregroundColor(.primary)
                .fontWeight(.bold)
        }
        .listRowBackground(Color.white.opacity(0.03))
    }
    
    private func usersSection(trip: Trip) -> some View {
        Section {
            Text(trip.users.joined(separator: ", "))
                .foregroundColor(.secondary)
                .font(.subheadline)
        } header: {
            Text("Users / Profiles")
                .foregroundColor(.primary)
                .fontWeight(.bold)
        }
        .listRowBackground(Color.white.opacity(0.03))
    }
    
    private func stepsSection(trip: Trip) -> some View {
        Section {
            ForEach(trip.steps) { step in
                NavigationLink(destination: DayEditorView(step: step, users: trip.users, store: store, onSave: { updatedStep in
                    updateStep(updatedStep)
                })) {
                    HStack(spacing: 12) {
                        Text("Day \(step.dayNumber)")
                            .font(.subheadline)
                            .fontWeight(.black)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .cornerRadius(8)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text(step.location.name)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.white.opacity(0.03))
            }
            .onDelete(perform: deleteStep)
            .onMove(perform: moveStep)
            
            Button(action: addStep) {
                Label("Add Day", systemImage: "calendar.badge.plus")
                    .fontWeight(.bold)
            }
            .listRowBackground(Color.white.opacity(0.03))
        } header: {
            HStack {
                Text("Days / Steps")
                    .foregroundColor(.primary)
                    .fontWeight(.bold)
                Spacer()
                Text("Drag to Reorder")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func saveChangesSection() -> some View {
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
        .listRowBackground(Color.accentColor.opacity(0.2))
    }
    
    // MARK: - Editor Operations
    
    private func setInitialMapPosition() {
        if let firstStep = editedTrip?.steps.first {
            let region = MKCoordinateRegion(
                center: firstStep.location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 12, longitudeDelta: 12)
            )
            mapPosition = .region(region)
        }
    }
    
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
    
    private func moveStep(from source: IndexSet, to destination: Int) {
        guard let trip = editedTrip else { return }
        var updatedSteps = trip.steps
        updatedSteps.move(fromOffsets: source, toOffset: destination)
        
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

struct DayLocationSearchResult: Hashable, Identifiable {
    let id = UUID()
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

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
    
    @State private var mapPosition: MapCameraPosition = .automatic
    
    @State private var locationSearchQuery = ""
    @State private var locationSearchResults = [DayLocationSearchResult]()
    @State private var isSearchingLocation = false
    
    var body: some View {
        ZStack {
            // Background Map showing the active day location
            Map(position: $mapPosition)
                .disabled(true)
                .ignoresSafeArea()
                .opacity(0.3)
                .blur(radius: 1.0)
            
            Color(.systemBackground)
                .opacity(0.2)
                .ignoresSafeArea()
            
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Step Title")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        TextField("Step Title", text: $step.title)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Date")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        TextField("Date", text: $step.date)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        TextField("Description", text: $step.description, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...6)
                    }
                    
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
                } header: {
                    Text("Day Properties")
                        .foregroundColor(.primary)
                        .fontWeight(.bold)
                }
                .listRowBackground(Color.white.opacity(0.03))
                
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Location Name")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        TextField("Location Name", text: $locName)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    if !locLat.isEmpty && !locLng.isEmpty {
                        HStack {
                            Text("Coordinates:")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(locLat), \(locLng)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField("Search Location in Apple Maps...", text: $locationSearchQuery)
                                .textFieldStyle(.roundedBorder)
                                .disableAutocorrection(true)
                                .autocapitalization(.none)
                            
                            Button("Search") {
                                performLocationSearch()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        
                        if isSearchingLocation {
                            ProgressView()
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 4)
                        } else if !locationSearchResults.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(locationSearchResults) { result in
                                        Button {
                                            locName = result.name
                                            locLat = String(result.latitude)
                                            locLng = String(result.longitude)
                                            locationSearchResults.removeAll()
                                            locationSearchQuery = ""
                                            
                                            let region = MKCoordinateRegion(
                                                center: result.coordinate,
                                                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                                            )
                                            mapPosition = .region(region)
                                        } label: {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(result.name)
                                                    .font(.caption)
                                                    .fontWeight(.bold)
                                                Text(result.address)
                                                    .font(.system(size: 8))
                                                    .foregroundColor(.secondary)
                                            }
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 12)
                                            .background(Color.accentColor.opacity(0.15))
                                            .cornerRadius(8)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                } header: {
                    Text("Location (Map integration)")
                        .foregroundColor(.primary)
                        .fontWeight(.bold)
                }
                .listRowBackground(Color.white.opacity(0.03))
                
                Section {
                    ForEach(step.items) { item in
                        NavigationLink(destination: ActivityEditorView(item: item, users: users, store: store, onSave: { updatedItem in
                            updateItem(updatedItem)
                        })) {
                            HStack(spacing: 12) {
                                Image(systemName: item.type.iconName)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.accentColor)
                                    .cornerRadius(8)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(item.title)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Text(item.time)
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.accentColor)
                                    }
                                    
                                    Text(item.details)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color.white.opacity(0.03))
                    }
                    .onDelete(perform: deleteItem)
                    .onMove(perform: moveItem)
                    
                    Button(action: addItem) {
                        Label("Add Activity", systemImage: "plus.circle")
                            .fontWeight(.bold)
                    }
                    .listRowBackground(Color.white.opacity(0.03))
                } header: {
                    HStack {
                        Text("Schedule & Activities")
                            .foregroundColor(.primary)
                            .fontWeight(.bold)
                        Spacer()
                        Text("Drag to Reorder")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        }
        .navigationTitle("Day \(step.dayNumber) Editor")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
        .onAppear {
            locName = step.location.name
            locLat = String(step.location.latitude)
            locLng = String(step.location.longitude)
            setInitialMapPosition()
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
    
    private func setInitialMapPosition() {
        let lat = Double(locLat) ?? step.location.latitude
        let lng = Double(locLng) ?? step.location.longitude
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
            span: MKCoordinateSpan(latitudeDelta: 2.0, longitudeDelta: 2.0)
        )
        mapPosition = .region(region)
    }
    
    private func performLocationSearch() {
        guard !locationSearchQuery.isEmpty else { return }
        isSearchingLocation = true
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = locationSearchQuery
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            isSearchingLocation = false
            guard let response = response else { return }
            locationSearchResults = response.mapItems.map { item in
                DayLocationSearchResult(
                    name: item.name ?? "Unknown Location",
                    address: item.placemark.title ?? "No Address",
                    latitude: item.placemark.coordinate.latitude,
                    longitude: item.placemark.coordinate.longitude
                )
            }
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
            flightNumber: nil,
            mapPlace: nil
        )
        let items = step.items + [newItem]
        step = Step(id: step.id, dayNumber: step.dayNumber, title: step.title, date: step.date, location: step.location, description: step.description, items: items)
    }
    
    private func deleteItem(at offsets: IndexSet) {
        var items = step.items
        items.remove(atOffsets: offsets)
        step = Step(id: step.id, dayNumber: step.dayNumber, title: step.title, date: step.date, location: step.location, description: step.description, items: items)
    }
    
    private func moveItem(from source: IndexSet, to destination: Int) {
        var items = step.items
        items.move(fromOffsets: source, toOffset: destination)
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
    
    @State private var mapPosition: MapCameraPosition = .automatic
    
    // Apple Maps place search state
    @State private var selectedMapPlace: MapPlaceInfo? = nil
    @State private var placeSearchQuery = ""
    @State private var placeSearchResults = [MapPlaceInfo]()
    @State private var isSearchingPlace = false
    
    // Server files list & selector
    @State private var serverFiles = [String]()
    @State private var showingFileSelector = false
    @State private var fileSelectorTarget: UploadTarget? = nil
    
    var body: some View {
        ZStack {
            // Background Map showing the active day location
            Map(position: $mapPosition)
                .disabled(true)
                .ignoresSafeArea()
                .opacity(0.3)
                .blur(radius: 1.0)
            
            Color(.systemBackground)
                .opacity(0.2)
                .ignoresSafeArea()
            
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
                .listRowBackground(Color.white.opacity(0.03))
                
                Section("Location & Place Details (Apple Maps)") {
                    if let place = selectedMapPlace {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(place.name)
                                    .fontWeight(.bold)
                                Spacer()
                                Button("Remove") {
                                    selectedMapPlace = nil
                                }
                                .foregroundColor(.red)
                                .buttonStyle(.borderless)
                            }
                            Text(place.address)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if let phone = place.phoneNumber {
                                Text("📞 \(phone)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        Text("No location associated with this activity.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField("Search Place in Apple Maps...", text: $placeSearchQuery)
                                .textFieldStyle(.roundedBorder)
                                .disableAutocorrection(true)
                                .autocapitalization(.none)
                            
                            Button("Search") {
                                performPlaceSearch()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        
                        if isSearchingPlace {
                            ProgressView()
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 4)
                        } else if !placeSearchResults.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(placeSearchResults, id: \.self) { result in
                                        Button {
                                            selectedMapPlace = result
                                            placeSearchResults.removeAll()
                                            placeSearchQuery = ""
                                            
                                            let region = MKCoordinateRegion(
                                                center: result.coordinate,
                                                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                                            )
                                            mapPosition = .region(region)
                                        } label: {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(result.name)
                                                    .font(.caption)
                                                    .fontWeight(.bold)
                                                Text(result.address)
                                                    .font(.system(size: 8))
                                                    .foregroundColor(.secondary)
                                            }
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 12)
                                            .background(Color.accentColor.opacity(0.15))
                                            .cornerRadius(8)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .listRowBackground(Color.white.opacity(0.03))
                
                if TripItemType.allCases[typeIndex] == .flight {
                    Section("Flight Status Tracking") {
                        TextField("Flight Number (e.g. AF372)", text: $flightNumberInput)
                            .autocapitalization(.allCharacters)
                            .disableAutocorrection(true)
                    }
                    .listRowBackground(Color.white.opacity(0.03))
                }
                
                Section("Links") {
                    TextField("Website URL", text: $websiteURLInput)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }
                .listRowBackground(Color.white.opacity(0.03))
                
                Section("PDF Ticket Files") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Shared Tickets (PDFs, Images):")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        let sharedFiles = sharedFilesInput.components(separatedBy: ",")
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                        
                        if sharedFiles.isEmpty {
                            Text("No files selected")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 4)
                        } else {
                            ForEach(sharedFiles, id: \.self) { file in
                                HStack {
                                    Image(systemName: "doc.text.fill")
                                        .foregroundColor(.accentColor)
                                    Text(file.components(separatedBy: "/").last ?? file)
                                        .font(.footnote)
                                        .lineLimit(1)
                                    Spacer()
                                    Button(role: .destructive) {
                                        let updated = sharedFiles.filter { $0 != file }.joined(separator: ", ")
                                        sharedFilesInput = updated
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .padding(8)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                        
                        HStack(spacing: 12) {
                            Button {
                                uploadingTarget = .sharedPDF
                                showingFilePicker = true
                            } label: {
                                Label("Upload New", systemImage: "icloud.and.arrow.up")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            
                            Button {
                                fileSelectorTarget = .sharedPDF
                                Task {
                                    serverFiles = await store.fetchServerFiles()
                                    showingFileSelector = true
                                }
                            } label: {
                                Label("Select Existing", systemImage: "folder")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 4)
                    
                    Text("Personal Tickets (per User):")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 6)
                    
                    ForEach(users, id: \.self) { user in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(user)
                                    .frame(width: 80, alignment: .leading)
                                
                                if let file = profileFiles[user], !file.isEmpty {
                                    HStack {
                                        Image(systemName: "doc.text.fill")
                                            .foregroundColor(.accentColor)
                                        Text(file.components(separatedBy: "/").last ?? file)
                                            .font(.footnote)
                                            .lineLimit(1)
                                        Spacer()
                                        Button(role: .destructive) {
                                            profileFiles.removeValue(forKey: user)
                                        } label: {
                                            Image(systemName: "trash")
                                                .font(.caption)
                                                .foregroundColor(.red)
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                    .padding(6)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(8)
                                } else {
                                    Text("No ticket selected")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            HStack(spacing: 12) {
                                Spacer()
                                    .frame(width: 80)
                                
                                Button {
                                    uploadingTarget = .profilePDF(user: user)
                                    showingFilePicker = true
                                } label: {
                                    Label("Upload", systemImage: "icloud.and.arrow.up")
                                        .font(.system(size: 11))
                                }
                                .buttonStyle(.bordered)
                                
                                Button {
                                    fileSelectorTarget = .profilePDF(user: user)
                                    Task {
                                        serverFiles = await store.fetchServerFiles()
                                        showingFileSelector = true
                                    }
                                } label: {
                                    Label("Select", systemImage: "folder")
                                        .font(.system(size: 11))
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listRowBackground(Color.white.opacity(0.03))
                
                Section("Apple Wallet Passes") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Shared Passes (e.g. passes/ticket.pkpass):")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        let sharedPasses = sharedPassesInput.components(separatedBy: ",")
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                        
                        if sharedPasses.isEmpty {
                            Text("No passes selected")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 4)
                        } else {
                            ForEach(sharedPasses, id: \.self) { passFile in
                                HStack {
                                    Image(systemName: "wallet.pass.fill")
                                        .foregroundColor(.orange)
                                    Text(passFile.components(separatedBy: "/").last ?? passFile)
                                        .font(.footnote)
                                        .lineLimit(1)
                                    Spacer()
                                    Button(role: .destructive) {
                                        let updated = sharedPasses.filter { $0 != passFile }.joined(separator: ", ")
                                        sharedPassesInput = updated
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .padding(8)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                        
                        HStack(spacing: 12) {
                            Button {
                                uploadingTarget = .sharedPass
                                showingFilePicker = true
                            } label: {
                                Label("Upload New", systemImage: "icloud.and.arrow.up")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            
                            Button {
                                fileSelectorTarget = .sharedPass
                                Task {
                                    serverFiles = await store.fetchServerFiles()
                                    showingFileSelector = true
                                }
                            } label: {
                                Label("Select Existing", systemImage: "folder")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 4)
                    
                    Text("Personal Passes (per User):")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 6)
                    
                    ForEach(users, id: \.self) { user in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(user)
                                    .frame(width: 80, alignment: .leading)
                                
                                if let pass = profilePasses[user], !pass.isEmpty {
                                    HStack {
                                        Image(systemName: "wallet.pass.fill")
                                            .foregroundColor(.orange)
                                        Text(pass.components(separatedBy: "/").last ?? pass)
                                            .font(.footnote)
                                            .lineLimit(1)
                                        Spacer()
                                        Button(role: .destructive) {
                                            profilePasses.removeValue(forKey: user)
                                        } label: {
                                            Image(systemName: "trash")
                                                .font(.caption)
                                                .foregroundColor(.red)
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                    .padding(6)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(8)
                                } else {
                                    Text("No pass selected")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            HStack(spacing: 12) {
                                Spacer()
                                    .frame(width: 80)
                                
                                Button {
                                    uploadingTarget = .profilePass(user: user)
                                    showingFilePicker = true
                                } label: {
                                    Label("Upload", systemImage: "icloud.and.arrow.up")
                                        .font(.system(size: 11))
                                }
                                .buttonStyle(.bordered)
                                
                                Button {
                                    fileSelectorTarget = .profilePass(user: user)
                                    Task {
                                        serverFiles = await store.fetchServerFiles()
                                        showingFileSelector = true
                                    }
                                } label: {
                                    Label("Select", systemImage: "folder")
                                        .font(.system(size: 11))
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listRowBackground(Color.white.opacity(0.03))
                
                if isUploadingFile {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Uploading file to server...")
                                .padding(.leading, 8)
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.03))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
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
        .sheet(isPresented: $showingFileSelector) {
            let isPassTarget: Bool = {
                if let target = fileSelectorTarget {
                    switch target {
                    case .sharedPass, .profilePass:
                        return true
                    default:
                        return false
                    }
                }
                return false
            }()
            
            FileSelectorView(
                files: serverFiles,
                filterPattern: isPassTarget ? ".pkpass" : ".pdf",
                onSelect: { selectedFile in
                    handleFileSelection(selectedFile)
                    showingFileSelector = false
                },
                onCancel: {
                    showingFileSelector = false
                }
            )
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
            
            selectedMapPlace = item.mapPlace
            
            setInitialMapPosition()
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
                flightNumber: flightNum.isEmpty ? nil : flightNum,
                mapPlace: selectedMapPlace
            )
            onSave(updatedItem)
        }
    }
    
    private func setInitialMapPosition() {
        if let place = selectedMapPlace {
            let region = MKCoordinateRegion(
                center: place.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
            mapPosition = .region(region)
        } else if let firstStep = store.trip?.steps.first {
            let region = MKCoordinateRegion(
                center: firstStep.location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 12, longitudeDelta: 12)
            )
            mapPosition = .region(region)
        }
    }
    
    private func performPlaceSearch() {
        guard !placeSearchQuery.isEmpty else { return }
        isSearchingPlace = true
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = placeSearchQuery
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            isSearchingPlace = false
            guard let response = response else { return }
            placeSearchResults = response.mapItems.map { item in
                let name = item.name ?? "Unknown Location"
                let address = item.placemark.title ?? "No Address"
                let phone = item.phoneNumber
                let web = item.url?.absoluteString
                let lat = item.placemark.coordinate.latitude
                let lng = item.placemark.coordinate.longitude
                
                let mockDetails = generateMockPlaceDetails(for: name)
                
                return MapPlaceInfo(
                    name: name,
                    address: address,
                    phoneNumber: phone,
                    websiteURL: web,
                    latitude: lat,
                    longitude: lng,
                    openingHours: mockDetails.openingHours,
                    description: mockDetails.description
                )
            }
        }
    }
    
    private func generateMockPlaceDetails(for name: String) -> (description: String, openingHours: String) {
        let hours = "Monday–Friday: 9:00 AM – 5:30 PM\nSaturday: 10:00 AM – 6:00 PM\nSunday: Closed"
        
        let lowercaseName = name.lowercased()
        let description: String
        if lowercaseName.contains("museum") || lowercaseName.contains("art") || lowercaseName.contains("gallery") {
            description = "A renowned cultural institution displaying historic collections, interactive exhibitions, and art pieces. Perfect for sightseeing and learning about local heritage."
        } else if lowercaseName.contains("park") || lowercaseName.contains("garden") || lowercaseName.contains("square") || lowercaseName.contains("canyon") || lowercaseName.contains("national") {
            description = "A beautiful public scenic space offering breathtaking views, hiking trails, and a tranquil escape. Ideal for relaxing and outdoor photos."
        } else if lowercaseName.contains("restaurant") || lowercaseName.contains("cafe") || lowercaseName.contains("kitchen") || lowercaseName.contains("grill") || lowercaseName.contains("bistro") || lowercaseName.contains("coffee") {
            description = "A highly rated dining establishment known for its vibrant ambiance, excellent service, and selection of local and international delicacies."
        } else {
            description = "A popular landmark and point of interest. Highly recommended for travelers looking to explore the best attractions and local culture in the area."
        }
        
        return (description, hours)
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
    
    private func handleFileSelection(_ file: String) {
        guard let target = fileSelectorTarget else { return }
        
        switch target {
        case .sharedPDF:
            let current = sharedFilesInput.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if !current.contains(file) {
                var updated = current
                updated.append(file)
                sharedFilesInput = updated.joined(separator: ", ")
            }
        case .profilePDF(let user):
            profileFiles[user] = file
        case .sharedPass:
            let current = sharedPassesInput.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if !current.contains(file) {
                var updated = current
                updated.append(file)
                sharedPassesInput = updated.joined(separator: ", ")
            }
        case .profilePass(let user):
            profilePasses[user] = file
        }
        
        if !store.downloadedFiles.contains(file) {
            Task {
                if let tripURL = URL(string: store.serverURLString) {
                    let remoteURL = tripURL.deletingLastPathComponent().appendingPathComponent(file)
                    try? await store.downloadFile(from: remoteURL, originalFilename: file)
                }
            }
        }
    }
}

struct FileSelectorView: View {
    let files: [String]
    let filterPattern: String
    let onSelect: (String) -> Void
    let onCancel: () -> Void
    
    @State private var searchQuery = ""
    
    var filteredFiles: [String] {
        files.filter { file in
            let lowercasedFile = file.lowercased()
            let matchFilter: Bool
            if filterPattern == ".pkpass" {
                matchFilter = lowercasedFile.hasSuffix(".pkpass")
            } else {
                matchFilter = !lowercasedFile.hasSuffix(".pkpass")
            }
            if !searchQuery.isEmpty {
                return matchFilter && lowercasedFile.contains(searchQuery.lowercased())
            }
            return matchFilter
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if filteredFiles.isEmpty {
                    Text("No matching files found on server.")
                        .foregroundColor(.secondary)
                        .italic()
                        .padding()
                } else {
                    ForEach(filteredFiles, id: \.self) { file in
                        Button {
                            onSelect(file)
                        } label: {
                            HStack {
                                Image(systemName: file.lowercased().hasSuffix(".pkpass") ? "wallet.pass" : "doc.text")
                                    .foregroundColor(.accentColor)
                                Text(file.components(separatedBy: "/").last ?? file)
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(file.components(separatedBy: "/").first ?? "")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.15))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Existing File")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchQuery, prompt: "Search files...")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }
}
