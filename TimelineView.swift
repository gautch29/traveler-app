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
    @State private var expandedPDFs: Set<String> = []
    
    // Stays & Flights animation and presentation states
    @State private var planeProgress: Double = 0.0
    @State private var expandedDays: Set<String> = []
    
    // In-Timeline Inline Editing States
    @State private var isTimelineEditMode = false
    @State private var editedTrip: Trip? = nil
    
    // File upload states in TimelineView
    @State private var showingFilePicker = false
    @State private var filePickerType: FileType = .ticket
    @State private var isUploadingFile = false
    @State private var fileUploadTargetStepId = ""
    @State private var showingUploadAlert = false
    @State private var uploadAlertMessage = ""
    
    enum FileType {
        case ticket
        case pass
    }
    
    public init(store: TripStore) {
        self.store = store
    }
    
    private var tripBinding: Binding<Trip>? {
        guard editedTrip != nil else { return nil }
        return Binding(
            get: { editedTrip! },
            set: { editedTrip = $0 }
        )
    }
    
    private func stepBinding(forId id: String) -> Binding<Step>? {
        guard let tripBinding = tripBinding else { return nil }
        guard let idx = editedTrip?.steps.firstIndex(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { tripBinding.wrappedValue.steps[idx] },
            set: { newStep in
                var updatedSteps = tripBinding.wrappedValue.steps
                updatedSteps[idx] = newStep
                tripBinding.wrappedValue = Trip(
                    tripName: tripBinding.wrappedValue.tripName,
                    startDate: tripBinding.wrappedValue.startDate,
                    endDate: tripBinding.wrappedValue.endDate,
                    users: tripBinding.wrappedValue.users,
                    emergencyInfo: tripBinding.wrappedValue.emergencyInfo,
                    steps: updatedSteps
                )
            }
        )
    }
    
    private func dayBinding(stepId: String, dayId: String) -> Binding<DayInfo>? {
        guard let stepBinding = stepBinding(forId: stepId) else { return nil }
        guard let days = stepBinding.wrappedValue.stayInfo?.days else { return nil }
        guard let idx = days.firstIndex(where: { $0.id == dayId }) else { return nil }
        return Binding(
            get: { days[idx] },
            set: { newDay in
                if var stay = stepBinding.wrappedValue.stayInfo {
                    stay.days[idx] = newDay
                    var step = stepBinding.wrappedValue
                    step.stayInfo = stay
                    stepBinding.wrappedValue = step
                }
            }
        )
    }
    
    private func itemBinding(stepId: String, dayId: String, itemId: String) -> Binding<TripItem>? {
        guard let dayBinding = dayBinding(stepId: stepId, dayId: dayId) else { return nil }
        guard let idx = dayBinding.wrappedValue.items.firstIndex(where: { $0.id == itemId }) else { return nil }
        return Binding(
            get: { dayBinding.wrappedValue.items[idx] },
            set: { newItem in
                var day = dayBinding.wrappedValue
                day.items[idx] = newItem
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
                handleFileImport(result: result)
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
    
    private func saveInlineEdits() {
        guard let trip = editedTrip else { return }
        store.trip = trip
        
        Task {
            let success = await store.uploadTrip()
            if success {
                await store.downloadAllFilesForCurrentConfig()
            }
            withAnimation {
                isTimelineEditMode = false
            }
        }
    }
    
    private func deleteStep(_ step: Step) {
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
    
    private func handleFileImport(result: Result<[URL], Error>) {
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
                let folderName = filePickerType == .pass ? "passes" : "tickets"
                let serverPath = "\(folderName)/\(rawFilename)"
                
                isUploadingFile = true
                Task {
                    let success = await store.uploadFile(data: fileData, filename: serverPath)
                    isUploadingFile = false
                    
                    if success {
                        // Check if it's a compound activity target step id
                        if fileUploadTargetStepId.contains("|") {
                            let parts = fileUploadTargetStepId.components(separatedBy: "|")
                            if parts.count == 3 {
                                let stepId = parts[0]
                                let dayId = parts[1]
                                let itemId = parts[2]
                                
                                if let itemBind = itemBinding(stepId: stepId, dayId: dayId, itemId: itemId) {
                                    var files = itemBind.wrappedValue.sharedFiles
                                    files.append(serverPath)
                                    itemBind.wrappedValue.sharedFiles = files
                                }
                            }
                        } else {
                            // Standard step target
                            if let binding = stepBinding(forId: fileUploadTargetStepId) {
                                if binding.wrappedValue.type == .stay {
                                    if var stay = binding.wrappedValue.stayInfo {
                                        if var hotel = stay.hotel {
                                            var shared = hotel.sharedFiles
                                            shared.append(serverPath)
                                            hotel.sharedFiles = shared
                                            stay.hotel = hotel
                                            binding.wrappedValue.stayInfo = stay
                                        } else {
                                            stay.hotel = TripItem(
                                                id: UUID().uuidString.lowercased(),
                                                type: .hotel,
                                                title: "New Accommodation",
                                                time: "",
                                                details: "Details",
                                                sharedFiles: [serverPath],
                                                profileFiles: nil,
                                                walletPasses: nil,
                                                profileWalletPasses: nil,
                                                websiteURL: nil,
                                                flightNumber: nil,
                                                mapPlace: nil
                                            )
                                            binding.wrappedValue.stayInfo = stay
                                        }
                                    }
                                } else {
                                    if var flight = binding.wrappedValue.flightInfo {
                                        if filePickerType == .pass {
                                            var passes = flight.walletPasses ?? []
                                            passes.append(serverPath)
                                            flight.walletPasses = passes
                                        } else {
                                            var shared = flight.sharedFiles ?? []
                                            shared.append(serverPath)
                                            flight.sharedFiles = shared
                                        }
                                        binding.wrappedValue.flightInfo = flight
                                    }
                                }
                            }
                        }
                        uploadAlertMessage = "File uploaded and attached successfully!"
                        showingUploadAlert = true
                    } else {
                        uploadAlertMessage = "Failed to upload file to the server."
                        showingUploadAlert = true
                    }
                }
            } catch {
                uploadAlertMessage = "Failed to read local file: \(error.localizedDescription)"
                showingUploadAlert = true
            }
            
        case .failure(let error):
            uploadAlertMessage = "File selection failed: \(error.localizedDescription)"
            showingUploadAlert = true
        }
    }
    
    // MARK: - Flight & Stay Card Views
    
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
    
    private func flightSummaryCard(_ step: Step) -> some View {
        guard let flight = step.flightInfo else { return AnyView(EmptyView()) }
        let type = step.type
        
        return AnyView(
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(type == .flight ? "FLIGHT" : (type == .train ? "TRAIN" : "ROAD TRIP"))
                        .font(.caption2)
                        .fontWeight(.black)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(type == .flight ? Color.blue : (type == .train ? Color.orange : Color.green))
                        .cornerRadius(6)
                    
                    Spacer()
                    
                    if !isTimelineEditMode {
                        Button {
                            withAnimation {
                                store.selectedStep = step
                                store.selectedTab = 1
                            }
                        } label: {
                            Image(systemName: "map.fill")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(6)
                                .background(Color.blue)
                                .clipShape(Circle())
                        }
                        .padding(.trailing, 4)
                    }
                    
                    Text(formatDateString(flight.date))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                }
                
                if isTimelineEditMode, let binding = stepBinding(forId: step.id) {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Step Title", text: binding.title)
                            .font(.title3)
                            .fontWeight(.bold)
                            .glassTextFieldStyle()
                        
                        HStack {
                            TextField("Operator (Airline/Car)", text: Binding(
                                get: { binding.wrappedValue.flightInfo?.airline ?? "" },
                                set: { binding.wrappedValue.flightInfo?.airline = $0 }
                            ))
                            .glassTextFieldStyle()
                            
                            TextField("Number/ID", text: Binding(
                                get: { binding.wrappedValue.flightInfo?.flightNumber ?? "" },
                                set: { binding.wrappedValue.flightInfo?.flightNumber = $0 }
                            ))
                            .glassTextFieldStyle()
                        }
                        
                        HStack {
                            Button(role: .destructive) {
                                deleteStep(step)
                            } label: {
                                Label("Delete Step", systemImage: "trash")
                                    .font(.caption)
                                    .fontWeight(.bold)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        }
                    }
                } else {
                    Text(step.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                HStack(alignment: .center) {
                    if isTimelineEditMode, let binding = stepBinding(forId: step.id) {
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("From", text: Binding(
                                get: { binding.wrappedValue.flightInfo?.departureAirport.name ?? "" },
                                set: { newName in
                                    if var info = binding.wrappedValue.flightInfo {
                                        info.departureAirport = LocationInfo(
                                            name: newName,
                                            latitude: info.departureAirport.latitude,
                                            longitude: info.departureAirport.longitude
                                        )
                                        binding.wrappedValue.flightInfo = info
                                    }
                                }
                            ))
                            .font(.caption)
                            .glassTextFieldStyle()
                            
                            TextField("Time", text: Binding(
                                get: { binding.wrappedValue.flightInfo?.departureTime ?? "" },
                                set: { binding.wrappedValue.flightInfo?.departureTime = $0 }
                            ))
                            .font(.caption)
                            .glassTextFieldStyle()
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 4) {
                            Image(systemName: type == .flight ? "airplane" : (type == .train ? "train.side.front.car" : "car.fill"))
                                .font(.headline)
                                .foregroundColor(.accentColor)
                            
                            Rectangle()
                                .fill(Color.accentColor.opacity(0.4))
                                .frame(height: 1)
                                .frame(width: 50)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 6) {
                            TextField("To", text: Binding(
                                get: { binding.wrappedValue.flightInfo?.arrivalAirport.name ?? "" },
                                set: { newName in
                                    if var info = binding.wrappedValue.flightInfo {
                                        info.arrivalAirport = LocationInfo(
                                            name: newName,
                                            latitude: info.arrivalAirport.latitude,
                                            longitude: info.arrivalAirport.longitude
                                        )
                                        binding.wrappedValue.flightInfo = info
                                    }
                                }
                            ))
                            .font(.caption)
                            .glassTextFieldStyle()
                            
                            TextField("Time", text: Binding(
                                get: { binding.wrappedValue.flightInfo?.arrivalTime ?? "" },
                                set: { binding.wrappedValue.flightInfo?.arrivalTime = $0 }
                            ))
                            .font(.caption)
                            .glassTextFieldStyle()
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(flight.departureAirport.name.components(separatedBy: " (").first ?? "DEP")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Text(flight.departureTime)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 4) {
                            Image(systemName: type == .flight ? "airplane" : (type == .train ? "train.side.front.car" : "car.fill"))
                                .font(.headline)
                                .foregroundColor(.accentColor)
                            
                            Rectangle()
                                .fill(Color.accentColor.opacity(0.4))
                                .frame(height: 1)
                                .frame(width: 80)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(flight.arrivalAirport.name.components(separatedBy: " (").first ?? "ARR")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Text(flight.arrivalTime)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
                
                Divider()
                
                if isTimelineEditMode, let binding = stepBinding(forId: step.id) {
                    TextField("Details", text: Binding(
                        get: { binding.wrappedValue.flightInfo?.details ?? "" },
                        set: { binding.wrappedValue.flightInfo?.details = $0 }
                    ))
                    .font(.subheadline)
                    .glassTextFieldStyle()
                } else {
                    Text(flight.details)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(20)
            .liquidGlassStyle(cornerRadius: 24, fillOpacity: 0.03, borderOpacity: 0.45)
        )
    }
    
    private func flightDetailsSection(_ step: Step) -> some View {
        guard let flight = step.flightInfo else { return AnyView(EmptyView()) }
        let type = step.type
        let user = store.selectedUser ?? ""
        var flightFiles: [String] = []
        if let shared = flight.sharedFiles { flightFiles.append(contentsOf: shared) }
        if let profile = flight.profileFiles?[user] { flightFiles.append(profile) }
        
        var flightPasses: [String] = []
        if let walletShared = flight.walletPasses { flightPasses.append(contentsOf: walletShared) }
        if let walletProfile = flight.profileWalletPasses?[user] { flightPasses.append(walletProfile) }
        
        return AnyView(
            VStack(alignment: .leading, spacing: 14) {
                if isTimelineEditMode, let binding = stepBinding(forId: step.id) {
                    Text("Itinerary Map Settings")
                        .font(.headline)
                        .fontWeight(.bold)
                        .padding(.leading, 4)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Departure Coordinates:")
                            .font(.caption)
                            .fontWeight(.bold)
                        HStack {
                            TextField("Lat", text: Binding(
                                get: { String(format: "%.4f", binding.wrappedValue.flightInfo?.departureAirport.latitude ?? 0.0) },
                                set: { newLatStr in
                                    if var info = binding.wrappedValue.flightInfo {
                                        let newLat = Double(newLatStr) ?? info.departureAirport.latitude
                                        info.departureAirport = LocationInfo(
                                            name: info.departureAirport.name,
                                            latitude: newLat,
                                            longitude: info.departureAirport.longitude
                                        )
                                        binding.wrappedValue.flightInfo = info
                                    }
                                }
                            ))
                            .glassTextFieldStyle()
                            
                            TextField("Lng", text: Binding(
                                get: { String(format: "%.4f", binding.wrappedValue.flightInfo?.departureAirport.longitude ?? 0.0) },
                                set: { newLngStr in
                                    if var info = binding.wrappedValue.flightInfo {
                                        let newLng = Double(newLngStr) ?? info.departureAirport.longitude
                                        info.departureAirport = LocationInfo(
                                            name: info.departureAirport.name,
                                            latitude: info.departureAirport.latitude,
                                            longitude: newLng
                                        )
                                        binding.wrappedValue.flightInfo = info
                                    }
                                }
                            ))
                            .glassTextFieldStyle()
                        }
                        
                        Text("Arrival Coordinates:")
                            .font(.caption)
                            .fontWeight(.bold)
                        HStack {
                            TextField("Lat", text: Binding(
                                get: { String(format: "%.4f", binding.wrappedValue.flightInfo?.arrivalAirport.latitude ?? 0.0) },
                                set: { newLatStr in
                                    if var info = binding.wrappedValue.flightInfo {
                                        let newLat = Double(newLatStr) ?? info.arrivalAirport.latitude
                                        info.arrivalAirport = LocationInfo(
                                            name: info.arrivalAirport.name,
                                            latitude: newLat,
                                            longitude: info.arrivalAirport.longitude
                                        )
                                        binding.wrappedValue.flightInfo = info
                                    }
                                }
                            ))
                            .glassTextFieldStyle()
                            
                            TextField("Lng", text: Binding(
                                get: { String(format: "%.4f", binding.wrappedValue.flightInfo?.arrivalAirport.longitude ?? 0.0) },
                                set: { newLngStr in
                                    if var info = binding.wrappedValue.flightInfo {
                                        let newLng = Double(newLngStr) ?? info.arrivalAirport.longitude
                                        info.arrivalAirport = LocationInfo(
                                            name: info.arrivalAirport.name,
                                            latitude: info.arrivalAirport.latitude,
                                            longitude: newLng
                                        )
                                        binding.wrappedValue.flightInfo = info
                                    }
                                }
                            ))
                            .glassTextFieldStyle()
                        }
                    }
                    .padding()
                    .liquidGlassStyle(cornerRadius: 16, fillOpacity: 0.015, borderOpacity: 0.25)
                }
                
                if type == .flight && !isTimelineEditMode {
                    Text("Live Flight Tracker")
                        .font(.headline)
                        .fontWeight(.bold)
                        .padding(.leading, 4)
                    
                    FlightStatusTrackerView(flightNumber: flight.flightNumber, date: flight.date, store: store)
                }
                
                if type == .car {
                    Text("Road Trip Route")
                        .font(.headline)
                        .fontWeight(.bold)
                        .padding(.leading, 4)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.green)
                                .font(.title3)
                            VStack(alignment: .leading) {
                                Text("Start Point")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(flight.departureAirport.name)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                            }
                        }
                        
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.down")
                                .foregroundColor(.secondary)
                                .font(.caption)
                                .padding(.leading, 6)
                            Text("Florida's Turnpike South (Approx. 4 hours)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 12) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.red)
                                .font(.title3)
                            VStack(alignment: .leading) {
                                Text("End Point")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(flight.arrivalAirport.name)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .liquidGlassStyle(cornerRadius: 16, fillOpacity: 0.015, borderOpacity: 0.25)
                }
                
                if isTimelineEditMode && type != .car {
                    Text("File Attachments Manager")
                        .font(.headline)
                        .fontWeight(.bold)
                        .padding(.leading, 4)
                        .padding(.top, 10)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Button {
                                filePickerType = .ticket
                                fileUploadTargetStepId = step.id
                                showingFilePicker = true
                            } label: {
                                Label("Upload PDF", systemImage: "doc.badge.plus")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.blue)
                                    .cornerRadius(8)
                            }
                            
                            Button {
                                filePickerType = .pass
                                fileUploadTargetStepId = step.id
                                showingFilePicker = true
                            } label: {
                                Label("Upload Pass", systemImage: "qrcode")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.purple)
                                    .cornerRadius(8)
                            }
                        }
                        
                        if let binding = stepBinding(forId: step.id) {
                            let shared = binding.wrappedValue.flightInfo?.sharedFiles ?? []
                            let wallet = binding.wrappedValue.flightInfo?.walletPasses ?? []
                            
                            if !shared.isEmpty || !wallet.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(shared, id: \.self) { file in
                                        HStack {
                                            Image(systemName: "doc.text")
                                                .foregroundColor(.secondary)
                                            Text(file.components(separatedBy: "/").last ?? file)
                                                .font(.caption)
                                                .lineLimit(1)
                                            Spacer()
                                            Button {
                                                if var fInfo = binding.wrappedValue.flightInfo {
                                                    var arr = fInfo.sharedFiles ?? []
                                                    if let idx = arr.firstIndex(of: file) {
                                                        arr.remove(at: idx)
                                                    }
                                                    fInfo.sharedFiles = arr
                                                    binding.wrappedValue.flightInfo = fInfo
                                                }
                                            } label: {
                                                Image(systemName: "minus.circle.fill")
                                                    .foregroundColor(.red)
                                            }
                                        }
                                        .padding(8)
                                        .liquidGlassStyle(cornerRadius: 8, fillOpacity: 0.02, borderOpacity: 0.25)
                                    }
                                    
                                    ForEach(wallet, id: \.self) { pass in
                                        HStack {
                                            Image(systemName: "qrcode")
                                                .foregroundColor(.secondary)
                                            Text(pass.components(separatedBy: "/").last ?? pass)
                                                .font(.caption)
                                                .lineLimit(1)
                                            Spacer()
                                            Button {
                                                if var fInfo = binding.wrappedValue.flightInfo {
                                                    var arr = fInfo.walletPasses ?? []
                                                    if let idx = arr.firstIndex(of: pass) {
                                                        arr.remove(at: idx)
                                                    }
                                                    fInfo.walletPasses = arr
                                                    binding.wrappedValue.flightInfo = fInfo
                                                }
                                            } label: {
                                                Image(systemName: "minus.circle.fill")
                                                    .foregroundColor(.red)
                                            }
                                        }
                                        .padding(8)
                                        .liquidGlassStyle(cornerRadius: 8, fillOpacity: 0.02, borderOpacity: 0.25)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .liquidGlassStyle(cornerRadius: 16, fillOpacity: 0.015, borderOpacity: 0.25)
                }
                
                if !isTimelineEditMode && type != .car && (!flightFiles.isEmpty || !flightPasses.isEmpty) {
                    Text("Tickets & Boarding Passes")
                        .font(.headline)
                        .fontWeight(.bold)
                        .padding(.leading, 4)
                        .padding(.top, 10)
                    
                    ForEach(flightFiles, id: \.self) { file in
                        if store.downloadedFiles.contains(file) {
                            HStack(spacing: 8) {
                                Button {
                                    if let url = store.getLocalFileURL(forFilename: file) {
                                        fileViewTitle = type == .flight ? "Boarding Pass" : "Train Ticket"
                                        selectedFileToView = IdentifiableURL(url: url)
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: type == .flight ? "airplane" : "tram.fill")
                                            .foregroundColor(.accentColor)
                                        Text(type == .flight ? "View Boarding Pass" : "View Train Ticket")
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity)
                                    .liquidGlassStyle(cornerRadius: 12, fillOpacity: 0.015, borderOpacity: 0.25)
                                }
                                
                                if let url = store.getLocalFileURL(forFilename: file) {
                                    ShareLink(item: url) {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.subheadline)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 12)
                                            .liquidGlassStyle(cornerRadius: 12, fillOpacity: 0.015, borderOpacity: 0.25)
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
                                HStack {
                                    Image(systemName: "arrow.down.circle")
                                        .foregroundColor(.accentColor)
                                    Text(type == .flight ? "Download Boarding Pass" : "Download Train Ticket")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.accentColor)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .liquidGlassStyle(cornerRadius: 12, fillOpacity: 0.015, borderOpacity: 0.25)
                            }
                        }
                    }
                    
                    ForEach(flightPasses, id: \.self) { passFile in
                        Button {
                            if let url = store.getLocalFileURL(forFilename: passFile) {
                                fileViewTitle = "Apple Wallet Pass"
                                selectedFileToView = IdentifiableURL(url: url)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "qrcode.viewfinder")
                                    .foregroundColor(.accentColor)
                                Text("Add to Apple Wallet")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "plus")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .liquidGlassStyle(cornerRadius: 12, fillOpacity: 0.015, borderOpacity: 0.25)
                        }
                    }
                }
            }
        )
    }
    
    private func staySummaryCard(_ step: Step, stay: StayStepInfo) -> some View {
        let user = store.selectedUser ?? ""
        let hotelFiles = stay.hotel?.getFiles(forUser: user) ?? []
        
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("STAY")
                    .font(.caption2)
                    .fontWeight(.black)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple)
                    .cornerRadius(6)
                
                Spacer()
                
                if !isTimelineEditMode {
                    Button {
                        withAnimation {
                            store.selectedStep = step
                            store.selectedTab = 1
                        }
                    } label: {
                        Image(systemName: "map.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color.purple)
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 4)
                }
                
                Text("\(stay.days.count) Days")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
            }
            
            if isTimelineEditMode, let binding = stepBinding(forId: step.id) {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Step Title", text: binding.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .glassTextFieldStyle()
                    
                    TextField("City Name", text: Binding(
                        get: { binding.wrappedValue.stayInfo?.cityName ?? "" },
                        set: { binding.wrappedValue.stayInfo?.cityName = $0 }
                    ))
                    .font(.subheadline)
                    .glassTextFieldStyle()
                    
                    HStack {
                        Button(role: .destructive) {
                            deleteStep(step)
                        } label: {
                            Label("Delete Step", systemImage: "trash")
                                .font(.caption)
                                .fontWeight(.bold)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                    .padding(.top, 4)
                }
            } else {
                Text(step.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                if let firstDay = stay.days.first, let lastDay = stay.days.last {
                    Text("\(formatDateStringShort(firstDay.date)) - \(formatDateStringShort(lastDay.date))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            if let hotel = stay.hotel {
                Divider()
                    .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "bed.double.fill")
                            .foregroundColor(.purple)
                            .font(.headline)
                        
                        Text("Hotel Accommodation")
                            .font(.caption)
                            .fontWeight(.black)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    
                    if isTimelineEditMode, let binding = stepBinding(forId: step.id) {
                        TextField("Hotel Title", text: Binding(
                            get: { binding.wrappedValue.stayInfo?.hotel?.title ?? "" },
                            set: { binding.wrappedValue.stayInfo?.hotel?.title = $0 }
                        ))
                        .font(.headline)
                        .glassTextFieldStyle()
                        
                        TextField("Hotel Details", text: Binding(
                            get: { binding.wrappedValue.stayInfo?.hotel?.details ?? "" },
                            set: { binding.wrappedValue.stayInfo?.hotel?.details = $0 }
                        ))
                        .font(.subheadline)
                        .glassTextFieldStyle()
                    } else {
                        Text(hotel.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(hotel.details)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    if let place = hotel.mapPlace {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(place.address)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            if let phone = place.phoneNumber {
                                Text("📞 \(phone)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack(spacing: 8) {
                                Button {
                                    openInMaps(coordinate: place.coordinate, name: place.name)
                                } label: {
                                    Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 10)
                                        .background(Color.blue)
                                        .cornerRadius(6)
                                }
                                
                                if let webString = place.websiteURL, let webURL = URL(string: webString) {
                                    Link(destination: webURL) {
                                        Label("Website", systemImage: "safari.fill")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 10)
                                            .liquidGlassStyle(cornerRadius: 6, fillOpacity: 0.05, borderOpacity: 0.3)
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .liquidGlassStyle(cornerRadius: 12, fillOpacity: 0.015, borderOpacity: 0.25)
                    }
                    
                    if isTimelineEditMode {
                        Text("Attached booking receipts:")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                        
                        HStack {
                            Button {
                                filePickerType = .ticket
                                fileUploadTargetStepId = step.id
                                showingFilePicker = true
                            } label: {
                                Label("Attach Receipt PDF", systemImage: "doc.badge.plus")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(6)
                                    .background(Color.purple)
                                    .cornerRadius(6)
                            }
                        }
                        
                        if let binding = stepBinding(forId: step.id) {
                            let hotelFiles = binding.wrappedValue.stayInfo?.hotel?.sharedFiles ?? []
                            if !hotelFiles.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(hotelFiles, id: \.self) { file in
                                        HStack {
                                            Image(systemName: "doc.text")
                                                .font(.caption2)
                                            Text(file.components(separatedBy: "/").last ?? file)
                                                .font(.system(size: 10))
                                                .lineLimit(1)
                                            Spacer()
                                            Button {
                                                if var stay = binding.wrappedValue.stayInfo, var hotel = stay.hotel {
                                                    var arr = hotel.sharedFiles
                                                    if let idx = arr.firstIndex(of: file) {
                                                        arr.remove(at: idx)
                                                    }
                                                    hotel.sharedFiles = arr
                                                    stay.hotel = hotel
                                                    binding.wrappedValue.stayInfo = stay
                                                }
                                            } label: {
                                                Image(systemName: "minus.circle.fill")
                                                    .foregroundColor(.red)
                                                    .font(.caption2)
                                            }
                                        }
                                        .padding(6)
                                        .liquidGlassStyle(cornerRadius: 8, fillOpacity: 0.02, borderOpacity: 0.2)
                                    }
                                }
                            }
                        }
                    }
                    
                    if !isTimelineEditMode {
                        ForEach(hotelFiles, id: \.self) { file in
                            if store.downloadedFiles.contains(file) {
                                Button {
                                    if let url = store.getLocalFileURL(forFilename: file) {
                                        fileViewTitle = "Hotel Booking"
                                        selectedFileToView = IdentifiableURL(url: url)
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "doc.text.fill")
                                            .foregroundColor(.purple)
                                        Text("View Hotel Booking Receipt")
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .liquidGlassStyle(cornerRadius: 8, fillOpacity: 0.05, borderOpacity: 0.3)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(24)
        .liquidGlassStyle(cornerRadius: 24, fillOpacity: 0.03, borderOpacity: 0.45)
    }
    
    private func stayDaysSection(_ step: Step, stay: StayStepInfo) -> some View {
        return VStack(alignment: .leading, spacing: 16) {
            if isTimelineEditMode, let binding = stepBinding(forId: step.id) {
                Button {
                    let newDayNumber = (binding.wrappedValue.stayInfo?.days.count ?? 0) + 1
                    let newDay = DayInfo(
                        dayNumber: newDayNumber,
                        date: "2026-08-18",
                        title: "New Day",
                        description: "Day description",
                        items: []
                    )
                    withAnimation {
                        binding.wrappedValue.stayInfo?.days.append(newDay)
                    }
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add New Day to Stay")
                    }
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
            }
            
            ForEach(stay.days) { day in
                VStack(alignment: .leading, spacing: 0) {
                    if isTimelineEditMode, let dayBind = dayBinding(stepId: step.id, dayId: day.id) {
                        // Edit Mode Day Header Card
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("DAY \(day.dayNumber)")
                                    .font(.caption2)
                                    .fontWeight(.black)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.blue)
                                    .cornerRadius(4)
                                
                                Spacer()
                                
                                Button(role: .destructive) {
                                    if let idx = stepBinding(forId: step.id)?.wrappedValue.stayInfo?.days.firstIndex(where: { $0.id == day.id }) {
                                        withAnimation {
                                            _ = stepBinding(forId: step.id)?.wrappedValue.stayInfo?.days.remove(at: idx)
                                        }
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                            }
                            
                            TextField("Day Title", text: dayBind.title)
                                .font(.headline)
                                .glassTextFieldStyle()
                            
                            TextField("Day Description", text: dayBind.description)
                                .font(.subheadline)
                                .glassTextFieldStyle()
                            
                            TextField("Date (YYYY-MM-DD)", text: dayBind.date)
                                .font(.caption)
                                .glassTextFieldStyle()
                        }
                        .padding()
                        .background(Color.white.opacity(0.04))
                    } else {
                        // Read Mode Day Header Card
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("DAY \(day.dayNumber)")
                                    .font(.caption2)
                                    .fontWeight(.black)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.blue)
                                    .cornerRadius(4)
                                
                                Text(day.title)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    if expandedDays.contains(day.id) {
                                        expandedDays.remove(day.id)
                                    } else {
                                        expandedDays.insert(day.id)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            Button {
                                withAnimation {
                                    store.selectedStep = step
                                    store.selectedDayId = day.id
                                    store.selectedTab = 1
                                }
                            } label: {
                                Image(systemName: "map.fill")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(6)
                                    .background(Color.blue)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.trailing, 4)
                            
                            Text(formatDateStringShort(day.date))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                                .padding(.trailing, 6)
                            
                            Image(systemName: "chevron.right")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .rotationEffect(.degrees(expandedDays.contains(day.id) ? 90 : 0))
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.02))
                    }
                    
                    if expandedDays.contains(day.id) || isTimelineEditMode {
                        Divider()
                            .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 14) {
                            if !isTimelineEditMode && !day.description.isEmpty {
                                Text(day.description)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                                    .padding(.top, 12)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            if !isTimelineEditMode && day.items.isEmpty {
                                Text("No activities planned. Free day!")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .italic()
                                    .padding(.horizontal)
                                    .padding(.bottom, 12)
                            } else {
                                VStack(spacing: 12) {
                                    ForEach(day.items) { item in
                                        if isTimelineEditMode, let itemBind = itemBinding(stepId: step.id, dayId: day.id, itemId: item.id) {
                                            VStack(alignment: .leading, spacing: 6) {
                                                HStack {
                                                    Image(systemName: item.type == .hotel ? "bed.double.fill" : "mappin.and.ellipse")
                                                        .foregroundColor(.accentColor)
                                                    
                                                    TextField("Time", text: itemBind.time)
                                                        .font(.caption)
                                                        .frame(width: 80)
                                                        .glassTextFieldStyle()
                                                    
                                                    Spacer()
                                                    
                                                    Button(role: .destructive) {
                                                        if let idx = dayBinding(stepId: step.id, dayId: day.id)?.wrappedValue.items.firstIndex(where: { $0.id == item.id }) {
                                                            withAnimation {
                                                                _ = dayBinding(stepId: step.id, dayId: day.id)?.wrappedValue.items.remove(at: idx)
                                                            }
                                                        }
                                                    } label: {
                                                        Image(systemName: "minus.circle.fill")
                                                            .foregroundColor(.red)
                                                    }
                                                }
                                                
                                                TextField("Activity Title", text: itemBind.title)
                                                    .font(.subheadline)
                                                    .fontWeight(.bold)
                                                    .glassTextFieldStyle()
                                                
                                                TextField("Details", text: itemBind.details)
                                                    .font(.caption)
                                                    .glassTextFieldStyle()
                                                
                                                // Activity file manager
                                                Text("Attached Files:")
                                                    .font(.caption2)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.secondary)
                                                    .padding(.top, 4)
                                                
                                                HStack(spacing: 8) {
                                                    Button {
                                                        filePickerType = .ticket
                                                        fileUploadTargetStepId = "\(step.id)|\(day.id)|\(item.id)"
                                                        showingFilePicker = true
                                                    } label: {
                                                        Label("Attach PDF", systemImage: "doc.badge.plus")
                                                            .font(.system(size: 10))
                                                            .padding(6)
                                                            .background(Color.blue)
                                                            .foregroundColor(.white)
                                                            .cornerRadius(6)
                                                    }
                                                }
                                                
                                                let itemFiles = itemBind.wrappedValue.sharedFiles
                                                if !itemFiles.isEmpty {
                                                    ForEach(itemFiles, id: \.self) { file in
                                                        HStack {
                                                            Image(systemName: "doc.text")
                                                                .font(.caption2)
                                                            Text(file.components(separatedBy: "/").last ?? file)
                                                                .font(.system(size: 10))
                                                                .lineLimit(1)
                                                            Spacer()
                                                            Button {
                                                                var arr = itemBind.wrappedValue.sharedFiles
                                                                if let idx = arr.firstIndex(of: file) {
                                                                    arr.remove(at: idx)
                                                                }
                                                                itemBind.wrappedValue.sharedFiles = arr
                                                            } label: {
                                                                Image(systemName: "minus.circle.fill")
                                                                    .foregroundColor(.red)
                                                                    .font(.caption2)
                                                            }
                                                        }
                                                        .padding(4)
                                                        .liquidGlassStyle(cornerRadius: 6, fillOpacity: 0.02, borderOpacity: 0.2)
                                                    }
                                                }
                                            }
                                            .padding()
                                            .background(Color.white.opacity(0.02))
                                            .cornerRadius(10)
                                        } else {
                                            activityItemCard(item, date: day.date)
                                        }
                                    }
                                    
                                    if isTimelineEditMode, let dayBind = dayBinding(stepId: step.id, dayId: day.id) {
                                        Button {
                                            let newItem = TripItem(
                                                id: UUID().uuidString.lowercased(),
                                                type: .activity,
                                                title: "New Activity",
                                                time: "12:00 PM",
                                                details: "Details",
                                                sharedFiles: [],
                                                profileFiles: nil,
                                                walletPasses: nil,
                                                profileWalletPasses: nil,
                                                websiteURL: nil,
                                                flightNumber: nil,
                                                mapPlace: nil
                                            )
                                            withAnimation {
                                                dayBind.wrappedValue.items.append(newItem)
                                            }
                                        } label: {
                                            HStack {
                                                Image(systemName: "plus.circle.fill")
                                                Text("Add Activity")
                                            }
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 12)
                                            .background(Color.green)
                                            .cornerRadius(6)
                                        }
                                        .padding(.top, 4)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 16)
                                .padding(.top, 8)
                            }
                        }
                    }
                }
                .liquidGlassStyle(cornerRadius: 18, fillOpacity: 0.03, borderOpacity: 0.45)
            }
        }
    }
    
    private func activityItemCard(_ item: TripItem, date: String) -> some View {
        let user = store.selectedUser ?? ""
        let files = item.getFiles(forUser: user)
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: item.type == .hotel ? "bed.double.fill" : "mappin.and.ellipse")
                    .foregroundColor(.accentColor)
                    .font(.footnote)
                
                Text(item.time)
                    .font(.caption)
                    .fontWeight(.black)
                    .foregroundColor(.secondary)
                
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            if !item.details.isEmpty {
                Text(item.details)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 24)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            if !files.isEmpty {
                Divider()
                    .padding(.leading, 24)
                
                ForEach(files, id: \.self) { file in
                    if store.downloadedFiles.contains(file) {
                        Button {
                            if let url = store.getLocalFileURL(forFilename: file) {
                                fileViewTitle = item.type == .flight ? "Boarding Pass" : (item.type == .train ? "Train Ticket" : "Activity Ticket")
                                selectedFileToView = IdentifiableURL(url: url)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "doc.text.fill")
                                    .foregroundColor(.accentColor)
                                Text("View Attached File")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading, 24)
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlassStyle(cornerRadius: 14, fillOpacity: 0.015, borderOpacity: 0.3)
    }
    
    @ViewBuilder
    private func dayZeroView(_ trip: Trip) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                Spacer()
                    .frame(height: 100)
                
                VStack(spacing: 8) {
                    Text("Welcome to")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    
                    Text(trip.tripName)
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: "calendar")
                            .foregroundColor(.accentColor)
                            .font(.title3)
                        Text("Dates: \(formatDateStringShort(trip.startDate)) to \(formatDateStringShort(trip.endDate))")
                            .fontWeight(.semibold)
                    }
                    
                    HStack(spacing: 12) {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(.accentColor)
                            .font(.title3)
                        Text("Travelers: \(trip.users.joined(separator: ", "))")
                            .fontWeight(.semibold)
                    }
                    
                    HStack(spacing: 12) {
                        Image(systemName: "phone.fill")
                            .foregroundColor(.accentColor)
                            .font(.title3)
                        Text("Emergency: \(trip.emergencyInfo)")
                            .fontWeight(.semibold)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .liquidGlassStyle(cornerRadius: 20, fillOpacity: 0.03, borderOpacity: 0.45)
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Trip Steps Summary")
                        .font(.headline)
                        .fontWeight(.bold)
                        .padding(.leading, 6)
                    
                    ForEach(Array(trip.steps.enumerated()), id: \.element.id) { index, step in
                        Button {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                activeDayIndex = index + 1
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(width: 20, height: 20)
                                    .background(step.type == .stay ? Color.purple : (step.type == .flight ? Color.blue : (step.type == .train ? Color.orange : Color.green)))
                                    .clipShape(Circle())
                                
                                Text(step.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                                
                                Spacer()
                                
                                Text(formatDateStringShort(step.date))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(10)
                            .contentShape(Rectangle())
                            .liquidGlassStyle(cornerRadius: 10, fillOpacity: 0.015, borderOpacity: 0.25)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                    .frame(height: 50)
            }
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
    
    private func openInMaps(coordinate: CLLocationCoordinate2D, name: String) {
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = name
        let launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
        mapItem.openInMaps(launchOptions: launchOptions)
    }
    
    private func getEmojiForStep(_ step: Step) -> String {
        let title = step.title.lowercased()
        let desc: String
        if step.type == .flight || step.type == .train || step.type == .car, let flight = step.flightInfo {
            desc = flight.details.lowercased()
        } else if step.type == .stay, let stay = step.stayInfo {
            desc = stay.cityName.lowercased()
        } else {
            desc = ""
        }
        
        if title.contains("flight") || title.contains("airport") || desc.contains("flight") {
            return "✈️"
        } else if title.contains("hotel") || title.contains("accommodation") {
            return "🏨"
        } else if title.contains("beach") || title.contains("key west") || title.contains("sea") {
            return "🏖️"
        } else if title.contains("park") || title.contains("everglades") || title.contains("nature") {
            return "🌲"
        } else if title.contains("motley") || title.contains("concert") || title.contains("show") {
            return "🤘"
        } else if title.contains("space") || title.contains("kennedy") || title.contains("nasa") {
            return "🚀"
        } else if title.contains("train") || title.contains("station") {
            return "🚊"
        } else if title.contains("drive") || title.contains("road trip") || title.contains("car") {
            return "🚗"
        } else {
            return "📍"
        }
    }
    
    private func getRouteCoordinates(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D, isCurved: Bool) -> [CLLocationCoordinate2D] {
        if !isCurved {
            return [from, to]
        }
        var coords: [CLLocationCoordinate2D] = []
        let steps = 30
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let lat = from.latitude + (to.latitude - from.latitude) * t
            let lng = from.longitude + (to.longitude - from.longitude) * t
            
            let curvature: Double = 2.0
            let offset = sin(t * .pi) * curvature
            coords.append(CLLocationCoordinate2D(latitude: lat + offset, longitude: lng))
        }
        return coords
    }
    
    private func getPlaneCoordinate(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D, progress: Double, isCurved: Bool) -> CLLocationCoordinate2D {
        let lat = from.latitude + (to.latitude - from.latitude) * progress
        let lng = from.longitude + (to.longitude - from.longitude) * progress
        if !isCurved {
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        let curvature: Double = 2.0
        let offset = sin(progress * .pi) * curvature
        return CLLocationCoordinate2D(latitude: lat + offset, longitude: lng)
    }
    
    private func getBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lon1 = from.longitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let lon2 = to.longitude * .pi / 180
        
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radians = atan2(y, x)
        return radians * 180 / .pi
    }
    
    private func startPlaneAnimation() {
        planeProgress = 0.0
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if planeProgress >= 1.0 {
                timer.invalidate()
            } else {
                planeProgress += 0.015
            }
        }
    }
}

// MARK: - Flight Status Tracker subview

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

// MARK: - Liquid Glass Modifier & Extensions

public struct LiquidGlassModifier: ViewModifier {
    public var cornerRadius: CGFloat
    public var fillOpacity: Double
    public var borderOpacity: Double
    
    public init(cornerRadius: CGFloat = 12, fillOpacity: Double = 0.03, borderOpacity: Double = 0.45) {
        self.cornerRadius = cornerRadius
        self.fillOpacity = fillOpacity
        self.borderOpacity = borderOpacity
    }
    
    public func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.thinMaterial)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.white.opacity(fillOpacity))
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(fillOpacity * 2.0),
                                    Color.white.opacity(0.005)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(borderOpacity),
                                Color.white.opacity(borderOpacity * 0.15),
                                Color.clear,
                                Color.white.opacity(borderOpacity * 0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.6
                    )
            )
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
    }
}

public struct GlassTextFieldModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.white.opacity(0.06))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
            )
            .foregroundColor(.primary)
    }
}

extension View {
    public func liquidGlassStyle(cornerRadius: CGFloat = 12, fillOpacity: Double = 0.03, borderOpacity: Double = 0.45) -> some View {
        self.modifier(LiquidGlassModifier(cornerRadius: cornerRadius, fillOpacity: fillOpacity, borderOpacity: borderOpacity))
    }
    
    public func glassTextFieldStyle() -> some View {
        self.modifier(GlassTextFieldModifier())
    }
}
