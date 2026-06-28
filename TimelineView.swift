import SwiftUI
import MapKit
import PassKit

public struct TimelineView: View {
    @ObservedObject var store: TripStore
    
    @State var activeDayIndex = 0
    @State var mapPosition: MapCameraPosition = .automatic
    @State var planeProgress: Double = 0.0
    
    // Inline editing states
    @State var isTimelineEditMode = false
    @State var editedTrip: Trip? = nil
    @State var editingDayIds: Set<String> = []
    @State var expandedDays: Set<String> = []
    
    // File upload/import states
    @State var showingFilePicker = false
    @State var showingUploadAlert = false
    @State var uploadAlertMessage = ""
    @State var selectedFileToView: IdentifiableURL? = nil
    @State var fileViewTitle: String = ""
    @State var fileImportCallback: ((URL) -> Void)? = nil
    
    public init(store: TripStore) {
        self.store = store
    }
    
    // MARK: - Binding Helpers
    
    func stepBinding(forId id: String) -> Binding<Step>? {
        guard isTimelineEditMode, editedTrip != nil else { return nil }
        return Binding(
            get: {
                self.editedTrip?.steps.first(where: { $0.id == id }) ?? Step(type: .stay, title: "", date: "")
            },
            set: { newValue in
                guard var trip = self.editedTrip else { return }
                if let idx = trip.steps.firstIndex(where: { $0.id == id }) {
                    trip.steps[idx] = newValue
                    self.editedTrip = trip
                }
            }
        )
    }
    
    func dayBinding(stepId: String, dayId: String) -> Binding<DayInfo>? {
        guard let stepBind = stepBinding(forId: stepId) else { return nil }
        return Binding(
            get: {
                stepBind.wrappedValue.stayInfo?.days.first(where: { $0.id == dayId }) ?? DayInfo(dayNumber: 0, date: "", title: "", description: "", items: [])
            },
            set: { newValue in
                guard var stay = stepBind.wrappedValue.stayInfo else { return }
                if let idx = stay.days.firstIndex(where: { $0.id == dayId }) {
                    stay.days[idx] = newValue
                    stepBind.wrappedValue.stayInfo = stay
                }
            }
        )
    }
    
    func itemBinding(stepId: String, dayId: String, itemId: String) -> Binding<TripItem>? {
        guard let dayBinding = dayBinding(stepId: stepId, dayId: dayId) else { return nil }
        return Binding(
            get: {
                dayBinding.wrappedValue.items.first(where: { $0.id == itemId }) ?? TripItem(
                    id: "",
                    type: .activity,
                    title: "",
                    time: "",
                    details: "",
                    sharedFiles: [],
                    profileFiles: nil,
                    walletPasses: nil,
                    profileWalletPasses: nil,
                    websiteURL: nil,
                    flightNumber: nil,
                    mapPlace: nil
                )
            },
            set: { newValue in
                var day = dayBinding.wrappedValue
                guard let idx = day.items.firstIndex(where: { $0.id == itemId }) else { return }
                day.items[idx] = newValue
                dayBinding.wrappedValue = day
            }
        )
    }
    
    public var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // 1. Dynamic Map Background (drawn content, route paths, animated vehicles)
                Map(position: $mapPosition) {
                    if let trip = (isTimelineEditMode ? editedTrip : store.trip) {
                        if activeDayIndex == 0 {
                            // USA overview mode: show all hotels
                            ForEach(trip.steps) { step in
                                if step.type == .stay, let stay = step.stayInfo, let hotelPlace = stay.hotel?.mapPlace {
                                    Marker(hotelPlace.name, systemImage: "bed.double.fill", coordinate: CLLocationCoordinate2D(latitude: hotelPlace.latitude, longitude: hotelPlace.longitude))
                                        .tint(.purple)
                                }
                            }
                        } else if activeDayIndex - 1 < trip.steps.count {
                            if trip.steps[activeDayIndex - 1].type == .flight || trip.steps[activeDayIndex - 1].type == .train || trip.steps[activeDayIndex - 1].type == .car {
                                if let flight = trip.steps[activeDayIndex - 1].flightInfo {
                                    Marker(flight.departureAirport.name, systemImage: trip.steps[activeDayIndex - 1].type == .flight ? "airplane.departure" : (trip.steps[activeDayIndex - 1].type == .train ? "train.side.front.car" : "car.fill"), coordinate: flight.departureAirport.coordinate)
                                        .tint(.blue)
                                    Marker(flight.arrivalAirport.name, systemImage: trip.steps[activeDayIndex - 1].type == .flight ? "airplane.arrival" : (trip.steps[activeDayIndex - 1].type == .train ? "train.side.rear.car" : "car.fill"), coordinate: flight.arrivalAirport.coordinate)
                                        .tint(.red)
                                    
                                    let isCurved = trip.steps[activeDayIndex - 1].type == .flight
                                    MapPolyline(coordinates: getRouteCoordinates(from: flight.departureAirport.coordinate, to: flight.arrivalAirport.coordinate, isCurved: isCurved))
                                        .stroke(.blue.opacity(0.8), lineWidth: 4)
                                    
                                    Annotation("Vehicle", coordinate: getPlaneCoordinate(from: flight.departureAirport.coordinate, to: flight.arrivalAirport.coordinate, progress: planeProgress, isCurved: isCurved), anchor: .center) {
                                        Image(systemName: trip.steps[activeDayIndex - 1].type == .flight ? "airplane" : (trip.steps[activeDayIndex - 1].type == .train ? "train.side.front.car" : "car.side.fill"))
                                            .font(.title2)
                                            .foregroundColor(.white)
                                            .padding(8)
                                            .background(Color.blue)
                                            .clipShape(Circle())
                                            .shadow(radius: 4)
                                            .rotationEffect(.degrees(getBearing(from: flight.departureAirport.coordinate, to: flight.arrivalAirport.coordinate) - (trip.steps[activeDayIndex - 1].type == .flight || trip.steps[activeDayIndex - 1].type == .car ? 90 : 0)))
                                    }
                                }
                            } else if trip.steps[activeDayIndex - 1].type == .stay, let stay = trip.steps[activeDayIndex - 1].stayInfo {
                                if let hotelPlace = stay.hotel?.mapPlace {
                                    Marker(hotelPlace.name, systemImage: "bed.double.fill", coordinate: CLLocationCoordinate2D(latitude: hotelPlace.latitude, longitude: hotelPlace.longitude))
                                        .tint(.purple)
                                }
                                ForEach(stay.days) { day in
                                    ForEach(day.items) { item in
                                        if let place = item.mapPlace {
                                            Marker(place.name, systemImage: "mappin.and.ellipse", coordinate: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude))
                                                .tint(.orange)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .disabled(true)
                .ignoresSafeArea()
                .opacity(0.45)
                .blur(radius: 0.8)
                
                // Dark mode / light mode tint overlay
                Color(.systemBackground)
                    .opacity(0.15)
                    .ignoresSafeArea()
                
                Group {
                    if let trip = (isTimelineEditMode ? editedTrip : store.trip) {
                        // 2. TabView for horizontal swiping
                        TabView(selection: $activeDayIndex) {
                            // Page 0: Day 0 Welcome Screen
                            dayZeroView(trip)
                                .tag(0)
                            
                            // Pages 1 to N: Stays & Flights Steps
                            ForEach(Array(trip.steps.enumerated()), id: \.element.id) { index, step in
                                ScrollView(showsIndicators: false) {
                                    VStack(spacing: 20) {
                                        Spacer()
                                            .frame(height: 20)
                                        
                                        if step.type == .flight || step.type == .train || step.type == .car {
                                            flightSummaryCard(step)
                                                .padding(.horizontal)
                                            
                                            flightDetailsSection(step)
                                                .padding(.horizontal)
                                        } else if step.type == .stay, let stay = step.stayInfo {
                                            staySummaryCard(step, stay: stay)
                                                .padding(.horizontal)
                                            
                                            stayDaysSection(step, stay: stay)
                                                .padding(.horizontal)
                                        }
                                        
                                        Spacer()
                                            .frame(height: 50)
                                    }
                                }
                                .tag(index + 1)
                            }
                            
                            if isTimelineEditMode {
                                ScrollView(showsIndicators: false) {
                                    VStack(spacing: 24) {
                                        Spacer()
                                            .frame(height: 80)
                                        
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 60))
                                            .foregroundColor(.accentColor)
                                        
                                        Text("Add Step to Trip")
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)
                                        
                                        VStack(spacing: 12) {
                                            Button { addStayStep() } label: {
                                                Label("Add Stay", systemImage: "house")
                                                    .font(.headline)
                                                    .foregroundColor(.white)
                                                    .frame(maxWidth: .infinity)
                                                    .padding()
                                                    .background(Color.purple)
                                                    .cornerRadius(12)
                                            }
                                            
                                            Button { addFlightStep() } label: {
                                                Label("Add Flight", systemImage: "airplane")
                                                    .font(.headline)
                                                    .foregroundColor(.white)
                                                    .frame(maxWidth: .infinity)
                                                    .padding()
                                                    .background(Color.blue)
                                                    .cornerRadius(12)
                                            }
                                            
                                            Button { addTrainStep() } label: {
                                                Label("Add Train", systemImage: "tram")
                                                    .font(.headline)
                                                    .foregroundColor(.white)
                                                    .frame(maxWidth: .infinity)
                                                    .padding()
                                                    .background(Color.orange)
                                                    .cornerRadius(12)
                                            }
                                            
                                            Button { addCarStep() } label: {
                                                Label("Add Road Trip", systemImage: "car")
                                                    .font(.headline)
                                                    .foregroundColor(.white)
                                                    .frame(maxWidth: .infinity)
                                                    .padding()
                                                    .background(Color.green)
                                                    .cornerRadius(12)
                                            }
                                        }
                                        .padding(.horizontal, 40)
                                        
                                        Spacer()
                                    }
                                }
                                .tag(trip.steps.count + 1)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                    } else {
                        emptyStateView
                    }
                }
                
                // 3. Top Gradient Blur Overlay
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .mask(
                        LinearGradient(
                            colors: [.black, .black.opacity(0.85), .black.opacity(0.5), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 110)
                    .ignoresSafeArea(edges: .top)
                    .allowsHitTesting(false)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        if activeDayIndex == 0 {
                            Text("hello")
                                .font(.system(size: 20, weight: .black, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.blue, Color.red],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            Text("🇺🇸")
                                .font(.title3)
                        } else if let trip = (isTimelineEditMode ? editedTrip : store.trip), activeDayIndex - 1 < trip.steps.count {
                            let step = trip.steps[activeDayIndex - 1]
                            Text(getEmojiForStep(step))
                                .font(.title3)
                            Text(getStepTitle(step))
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundColor(.primary)
                        } else if isTimelineEditMode, activeDayIndex - 1 == (editedTrip?.steps.count ?? 0) {
                            Text("➕")
                            Text("Add Step")
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 14) {
                        if isTimelineEditMode {
                            Button("Cancel") {
                                let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("TravelerTemp")
                                try? FileManager.default.removeItem(at: tempDir)
                                
                                withAnimation {
                                    isTimelineEditMode = false
                                    editedTrip = nil
                                    if let trip = store.trip, activeDayIndex > trip.steps.count {
                                        activeDayIndex = trip.steps.count
                                    }
                                }
                            }
                            .foregroundColor(.red)
                            
                            Button("Save") {
                                saveInlineEdits()
                            }
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        } else {
                            Button {
                                withAnimation {
                                    editedTrip = store.trip
                                    isTimelineEditMode = true
                                }
                            } label: {
                                Image(systemName: "square.and.pencil")
                            }
                            
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
            .sheet(item: $selectedFileToView) { identifiableURL in
                if identifiableURL.url.pathExtension.lowercased() == "pkpass" {
                    WalletPassView(passURL: identifiableURL.url)
                } else {
                    PDFKitView(fileURL: identifiableURL.url, title: fileViewTitle)
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.pdf, .data],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let selectedURL = urls.first else { return }
                    fileImportCallback?(selectedURL)
                case .failure(let error):
                    uploadAlertMessage = "File selection failed: \(error.localizedDescription)"
                    showingUploadAlert = true
                }
            }
            .alert("Update", isPresented: $showingUploadAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(uploadAlertMessage)
            }
            .onAppear {
                setInitialMapPosition()
                startPlaneAnimation()
            }
            .onChange(of: store.trip) { _, _ in
                setInitialMapPosition()
            }
            .onChange(of: activeDayIndex) { (oldIdx: Int, newIdx: Int) in
                updateMapPosition(forIndex: newIdx)
                startPlaneAnimation()
            }
        }
    }
    
    // MARK: - Map Panning Animation
    
    private func setInitialMapPosition() {
        if let trip = store.trip, !trip.steps.isEmpty {
            updateMapPosition(forIndex: activeDayIndex)
        }
    }
    
    private func updateMapPosition(forIndex index: Int) {
        guard let trip = (isTimelineEditMode ? editedTrip : store.trip) else { return }
        
        let targetRegion: MKCoordinateRegion
        if index == 0 {
            // Cap coordinates of Cap Canaveral or NY to display USA
            targetRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.0902, longitude: -95.7129),
                span: MKCoordinateSpan(latitudeDelta: 24, longitudeDelta: 44)
            )
        } else if index - 1 < trip.steps.count {
            let step = trip.steps[index - 1]
            if step.type == .flight || step.type == .train || step.type == .car, let flight = step.flightInfo {
                let centerLat = (flight.departureAirport.latitude + flight.arrivalAirport.latitude) / 2
                let centerLng = (flight.departureAirport.longitude + flight.arrivalAirport.longitude) / 2
                let latDelta = abs(flight.departureAirport.latitude - flight.arrivalAirport.latitude) * 1.5 + 2.0
                let lngDelta = abs(flight.departureAirport.longitude - flight.arrivalAirport.longitude) * 1.5 + 2.0
                targetRegion = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLng),
                    span: MKCoordinateSpan(latitudeDelta: max(latDelta, 0.5), longitudeDelta: max(lngDelta, 0.5))
                )
            } else if step.type == .stay, let stay = step.stayInfo {
                let coord: CLLocationCoordinate2D
                if let hotelPlace = stay.hotel?.mapPlace {
                    coord = CLLocationCoordinate2D(latitude: hotelPlace.latitude, longitude: hotelPlace.longitude)
                } else {
                    coord = getCenterCoordinate(forCityName: stay.cityName)
                }
                targetRegion = MKCoordinateRegion(
                    center: coord,
                    span: MKCoordinateSpan(latitudeDelta: 0.22, longitudeDelta: 0.22)
                )
            } else {
                return
            }
        } else {
            return
        }
        
        withAnimation(.easeInOut(duration: 1.6)) {
            mapPosition = .region(targetRegion)
        }
    }
    
    // MARK: - Operations
    
    func stageFile(selectedURL: URL, type: String) -> String? {
        let gotAccess = selectedURL.startAccessingSecurityScopedResource()
        defer {
            if gotAccess {
                selectedURL.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            let fileData = try Data(contentsOf: selectedURL)
            let filename = selectedURL.lastPathComponent
            let uuid = UUID().uuidString.lowercased()
            
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("TravelerTemp")
                .appendingPathComponent(uuid)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
            
            let localURL = tempDir.appendingPathComponent(filename)
            try fileData.write(to: localURL)
            
            return createTempURL(uuid: uuid, filename: filename, type: type)
        } catch {
            print("Failed to stage file: \(error)")
            return nil
        }
    }
    
    private func uploadStagedFile(_ path: String) async -> String? {
        guard path.hasPrefix("temp://") else { return nil }
        guard let staged = parseTempURL(path) else { return nil }
        
        do {
            let data = try Data(contentsOf: staged.localURL)
            let folder = staged.type == "pass" ? "passes" : "tickets"
            let serverPath = "\(folder)/\(staged.originalFilename)"
            
            let success = await store.uploadFile(data: data, filename: serverPath)
            if success {
                let localCacheURL = store.localURL(forFilename: serverPath)
                try? FileManager.default.createDirectory(at: localCacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                if FileManager.default.fileExists(atPath: localCacheURL.path) {
                    try? FileManager.default.removeItem(at: localCacheURL)
                }
                try? FileManager.default.copyItem(at: staged.localURL, to: localCacheURL)
                
                await MainActor.run {
                    _ = store.downloadedFiles.insert(serverPath)
                }
                return serverPath
            }
        } catch {
            print("Failed to upload staged file: \(error)")
        }
        return nil
    }
    
    private func saveInlineEdits() {
        guard var trip = editedTrip else { return }
        
        Task {
            var uploadFailed = false
            
            // 1. Process and upload all staged files in the trip
            for i in 0..<trip.steps.count {
                var step = trip.steps[i]
                
                // A. Check flightInfo
                if var flight = step.flightInfo {
                    if var shared = flight.sharedFiles {
                        for j in 0..<shared.count {
                            if shared[j].hasPrefix("temp://") {
                                if let serverPath = await uploadStagedFile(shared[j]) {
                                    shared[j] = serverPath
                                } else {
                                    uploadFailed = true
                                }
                            }
                        }
                        flight.sharedFiles = shared
                    }
                    if var wallet = flight.walletPasses {
                        for j in 0..<wallet.count {
                            if wallet[j].hasPrefix("temp://") {
                                if let serverPath = await uploadStagedFile(wallet[j]) {
                                    wallet[j] = serverPath
                                } else {
                                    uploadFailed = true
                                }
                            }
                        }
                        flight.walletPasses = wallet
                    }
                    step.flightInfo = flight
                }
                
                // B. Check stayInfo
                if var stay = step.stayInfo {
                    if var hotel = stay.hotel {
                        var shared = hotel.sharedFiles
                        for j in 0..<shared.count {
                            if shared[j].hasPrefix("temp://") {
                                if let serverPath = await uploadStagedFile(shared[j]) {
                                    shared[j] = serverPath
                                } else {
                                    uploadFailed = true
                                }
                            }
                        }
                        hotel.sharedFiles = shared
                        
                        if var wallet = hotel.walletPasses {
                            for j in 0..<wallet.count {
                                if wallet[j].hasPrefix("temp://") {
                                    if let serverPath = await uploadStagedFile(wallet[j]) {
                                        wallet[j] = serverPath
                                    } else {
                                        uploadFailed = true
                                    }
                                }
                            }
                            hotel.walletPasses = wallet
                        }
                        stay.hotel = hotel
                    }
                    
                    for d in 0..<stay.days.count {
                        var day = stay.days[d]
                        for it in 0..<day.items.count {
                            var item = day.items[it]
                            
                            var shared = item.sharedFiles
                            for j in 0..<shared.count {
                                if shared[j].hasPrefix("temp://") {
                                    if let serverPath = await uploadStagedFile(shared[j]) {
                                        shared[j] = serverPath
                                    } else {
                                        uploadFailed = true
                                    }
                                }
                            }
                            item.sharedFiles = shared
                            
                            if var wallet = item.walletPasses {
                                for j in 0..<wallet.count {
                                    if wallet[j].hasPrefix("temp://") {
                                        if let serverPath = await uploadStagedFile(wallet[j]) {
                                            wallet[j] = serverPath
                                        } else {
                                            uploadFailed = true
                                        }
                                    }
                                }
                                item.walletPasses = wallet
                            }
                            day.items[it] = item
                        }
                        stay.days[d] = day
                    }
                    step.stayInfo = stay
                }
                
                trip.steps[i] = step
            }
            
            if uploadFailed {
                await MainActor.run {
                    uploadAlertMessage = "Failed to upload one or more staged attachments."
                    showingUploadAlert = true
                }
                return
            }
            
            // 2. Save trip config on the server
            store.trip = trip
            let success = await store.uploadTrip()
            if success {
                await store.downloadAllFilesForCurrentConfig()
                
                let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("TravelerTemp")
                try? FileManager.default.removeItem(at: tempDir)
            }
            
            await MainActor.run {
                withAnimation {
                    isTimelineEditMode = false
                }
            }
        }
    }
    
    func deleteStep(_ step: Step) {
        guard let trip = editedTrip else { return }
        var updatedSteps = trip.steps
        if let idx = updatedSteps.firstIndex(where: { $0.id == step.id }) {
            withAnimation {
                updatedSteps.remove(at: idx)
                editedTrip = Trip(
                    tripName: trip.tripName,
                    startDate: trip.startDate,
                    endDate: trip.endDate,
                    users: trip.users,
                    emergencyInfo: trip.emergencyInfo,
                    steps: updatedSteps
                )
                if activeDayIndex > (editedTrip?.steps.count ?? 0) {
                    activeDayIndex = editedTrip?.steps.count ?? 0
                }
            }
        }
    }
    
    private func addStayStep() {
        guard let trip = editedTrip else { return }
        let newStep = Step(
            type: .stay,
            title: "New Stay in City",
            date: "2026-08-18",
            stayInfo: StayStepInfo(cityName: "New City", hotel: nil, days: [])
        )
        withAnimation {
            editedTrip = Trip(
                tripName: trip.tripName,
                startDate: trip.startDate,
                endDate: trip.endDate,
                users: trip.users,
                emergencyInfo: trip.emergencyInfo,
                steps: trip.steps + [newStep]
            )
            activeDayIndex = (editedTrip?.steps.count ?? 0)
        }
    }
    
    private func addFlightStep() {
        guard let trip = editedTrip else { return }
        let newStep = Step(
            type: .flight,
            title: "New Flight Route",
            date: "2026-08-18",
            flightInfo: FlightStepInfo(
                flightNumber: "BF000",
                airline: "New Airline",
                departureAirport: LocationInfo(name: "Departure Airport", latitude: 37.0902, longitude: -95.7129),
                arrivalAirport: LocationInfo(name: "Arrival Airport", latitude: 37.0902, longitude: -95.7129),
                departureTime: "12:00 PM",
                arrivalTime: "3:00 PM",
                date: "2026-08-18",
                details: "Edit flight details."
            )
        )
        withAnimation {
            editedTrip = Trip(
                tripName: trip.tripName,
                startDate: trip.startDate,
                endDate: trip.endDate,
                users: trip.users,
                emergencyInfo: trip.emergencyInfo,
                steps: trip.steps + [newStep]
            )
            activeDayIndex = (editedTrip?.steps.count ?? 0)
        }
    }
    
    private func addTrainStep() {
        guard let trip = editedTrip else { return }
        let newStep = Step(
            type: .train,
            title: "New Train Journey",
            date: "2026-08-18",
            flightInfo: FlightStepInfo(
                flightNumber: "TR000",
                airline: "New Train Operator",
                departureAirport: LocationInfo(name: "Departure Station", latitude: 37.0902, longitude: -95.7129),
                arrivalAirport: LocationInfo(name: "Arrival Station", latitude: 37.0902, longitude: -95.7129),
                departureTime: "12:00 PM",
                arrivalTime: "3:00 PM",
                date: "2026-08-18",
                details: "Edit train details."
            )
        )
        withAnimation {
            editedTrip = Trip(
                tripName: trip.tripName,
                startDate: trip.startDate,
                endDate: trip.endDate,
                users: trip.users,
                emergencyInfo: trip.emergencyInfo,
                steps: trip.steps + [newStep]
            )
            activeDayIndex = (editedTrip?.steps.count ?? 0)
        }
    }
    
    private func addCarStep() {
        guard let trip = editedTrip else { return }
        let newStep = Step(
            type: .car,
            title: "New Road Trip",
            date: "2026-08-18",
            flightInfo: FlightStepInfo(
                flightNumber: "Drive",
                airline: "Rental Car",
                departureAirport: LocationInfo(name: "Start Point", latitude: 37.0902, longitude: -95.7129),
                arrivalAirport: LocationInfo(name: "End Point", latitude: 37.0902, longitude: -95.7129),
                departureTime: "12:00 PM",
                arrivalTime: "3:00 PM",
                date: "2026-08-18",
                details: "Edit road trip details."
            )
        )
        withAnimation {
            editedTrip = Trip(
                tripName: trip.tripName,
                startDate: trip.startDate,
                endDate: trip.endDate,
                users: trip.users,
                emergencyInfo: trip.emergencyInfo,
                steps: trip.steps + [newStep]
            )
            activeDayIndex = (editedTrip?.steps.count ?? 0)
        }
    }
    
    // MARK: - Helper getters
    
    private func getStepTitle(_ step: Step) -> String {
        switch step.type {
        case .flight:
            return "Flight \(step.flightInfo?.flightNumber ?? "")"
        case .train:
            return "Train \(step.flightInfo?.flightNumber ?? "")"
        case .car:
            return "Drive: \(step.flightInfo?.flightNumber ?? "")"
        case .stay:
            return "Stay: \(step.stayInfo?.cityName ?? "")"
        }
    }
    
    private func getCenterCoordinate(forCityName city: String) -> CLLocationCoordinate2D {
        switch city.lowercased() {
        case "new york":
            return CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        case "washington":
            return CLLocationCoordinate2D(latitude: 38.9072, longitude: -77.0369)
        case "orlando":
            return CLLocationCoordinate2D(latitude: 28.5383, longitude: -81.3792)
        case "miami":
            return CLLocationCoordinate2D(latitude: 25.7617, longitude: -80.1918)
        case "key west":
            return CLLocationCoordinate2D(latitude: 24.5551, longitude: -81.7800)
        case "cap canaveral":
            return CLLocationCoordinate2D(latitude: 28.3922, longitude: -80.6077)
        case "paris":
            return CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522)
        default:
            return CLLocationCoordinate2D(latitude: 37.0902, longitude: -95.7129)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 80))
                .foregroundColor(.secondary)
            Text("No Trip Configured")
                .font(.headline)
        }
    }
}
