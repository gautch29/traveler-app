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
    
    public init(store: TripStore) {
        self.store = store
    }
    
    public var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // 1. Dynamic Map Background (drawn content, route paths, animated vehicles)
                Map(position: $mapPosition) {
                    if let trip = store.trip {
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
                    if let trip = store.trip {
                        // 2. TabView for horizontal "Tinder card" swiping
                        TabView(selection: $activeDayIndex) {
                            // Page 0: Day 0 Welcome Hello Screen
                            dayZeroView(trip)
                                .tag(0)
                            
                            // Pages 1 to N: Stays & Flights Steps
                            ForEach(Array(trip.steps.enumerated()), id: \.element.id) { index, step in
                                ScrollView(showsIndicators: false) {
                                    VStack(spacing: 20) {
                                        Spacer()
                                            .frame(height: 20)
                                        
                                        if step.type == .flight || step.type == .train || step.type == .car {
                                            if let flight = step.flightInfo {
                                                flightSummaryCard(flight, type: step.type)
                                                    .padding(.horizontal)
                                                
                                                flightDetailsSection(flight, type: step.type)
                                                    .padding(.horizontal)
                                            }
                                        } else if step.type == .stay, let stay = step.stayInfo {
                                            staySummaryCard(step, stay: stay)
                                                .padding(.horizontal)
                                            
                                            stayDaysSection(stay)
                                                .padding(.horizontal)
                                        }
                                        
                                        Spacer()
                                            .frame(height: 50)
                                    }
                                }
                                .tag(index + 1)
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
                        } else if let trip = store.trip, activeDayIndex - 1 < trip.steps.count {
                            let step = trip.steps[activeDayIndex - 1]
                            Text(getEmojiForStep(step))
                                .font(.title3)
                            Text(getStepTitle(step))
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundColor(.primary)
                        }
                    }
                }
                
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
                startPlaneAnimation()
            }
            .onChange(of: store.trip) { _, _ in
                setInitialMapPosition()
            }
            .onChange(of: activeDayIndex) { _, newIndex in
                updateMapPosition(forIndex: newIndex)
                startPlaneAnimation()
            }
        }
    }
    
    // MARK: - Map Panning Animation
    
    private func startPlaneAnimation() {
        planeProgress = 0.0
        withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
            planeProgress = 1.0
        }
    }
    
    private func setInitialMapPosition() {
        guard let trip = store.trip, !trip.steps.isEmpty, !initialMapSet else { return }
        if let todayIndex = todayStepIndex(for: trip) {
            activeDayIndex = todayIndex + 1
        }
        updateMapPosition(forIndex: activeDayIndex, animated: false)
        initialMapSet = true
    }
    
    private func todayStepIndex(for trip: Trip) -> Int? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: Date())
        return trip.steps.firstIndex { $0.date == todayString }
    }
    
    private func updateMapPosition(forIndex index: Int, animated: Bool = true) {
        guard let trip = store.trip else { return }
        
        let targetRegion: MKCoordinateRegion
        if index == 0 {
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
        
        if animated {
            withAnimation(.spring(response: 0.95, dampingFraction: 0.82)) {
                mapPosition = .region(targetRegion)
            }
        } else {
            mapPosition = .region(targetRegion)
        }
    }
    
    // MARK: - Day 0 Welcome View
    
    private func dayZeroView(_ trip: Trip) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                Spacer()
                    .frame(height: 20)
                
                // USA Color Gradient Welcome Card
                dayZeroWelcomeCard(trip)
                    .padding(.horizontal)
                
                // Emergency info & summary details
                dayZeroDetailsSection(trip)
                    .padding(.horizontal)
                
                Spacer()
                    .frame(height: 50)
            }
        }
    }
    
    private func dayZeroWelcomeCard(_ trip: Trip) -> some View {
        VStack(spacing: 18) {
            HStack {
                Text("LET'S GO")
                    .font(.caption2)
                    .fontWeight(.black)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .cornerRadius(6)
                
                Spacer()
                
                Text("🇺🇸 ADVENTURE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white.opacity(0.85))
            }
            
            VStack(spacing: 4) {
                Text("hello.")
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.12), radius: 5, x: 0, y: 3)
                
                Text(trip.tripName)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 10)
            
            Divider()
                .background(Color.white.opacity(0.4))
            
            VStack(spacing: 6) {
                Text("\(formatDateString(trip.startDate)) to \(formatDateString(trip.endDate))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("3 Weeks • 4 Travelers")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.9))
            }
            
            // Glass pills for travelers
            HStack(spacing: 8) {
                ForEach(trip.users, id: \.self) { name in
                    Text(name)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.4))
            
            HStack {
                Text("Swipe left to start the journey")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundColor(.white.opacity(0.9))
                
                Image(systemName: "chevron.right.2")
                    .font(.footnote)
                    .foregroundColor(.white)
                    .opacity(0.8)
            }
            .padding(.top, 4)
        }
        .padding(24)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.75),
                                Color.indigo.opacity(0.65),
                                Color.red.opacity(0.75)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.25),
                                Color.white.opacity(0.02),
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
                            Color.white.opacity(0.7),
                            Color.white.opacity(0.15),
                            Color.clear,
                            Color.white.opacity(0.25)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 8)
    }
    
    private func dayZeroDetailsSection(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Emergency Contacts & Info 🚨")
                .font(.headline)
                .fontWeight(.bold)
                .padding(.leading, 4)
            
            VStack(alignment: .leading, spacing: 14) {
                ForEach(trip.emergencyInfo.numbers) { num in
                    Button {
                        if let url = URL(string: "tel://\(num.number.replacingOccurrences(of: " ", with: ""))") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "phone.fill")
                                .foregroundColor(.green)
                            
                            Text(num.label)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text(num.number)
                                .font(.subheadline)
                                .foregroundColor(.accentColor)
                                .fontWeight(.semibold)
                        }
                        .padding()
                        .liquidGlassStyle(cornerRadius: 12, fillOpacity: 0.015, borderOpacity: 0.25)
                    }
                }
                
                Text(trip.emergencyInfo.notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
            .padding()
            .liquidGlassStyle(cornerRadius: 20, fillOpacity: 0.03, borderOpacity: 0.45)
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
        case "paris":
            return CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522)
        default:
            return CLLocationCoordinate2D(latitude: 37.0902, longitude: -95.7129)
        }
    }
    
    private func getBearing(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> Double {
        let lat1 = start.latitude * .pi / 180
        let lon1 = start.longitude * .pi / 180
        let lat2 = end.latitude * .pi / 180
        let lon2 = end.longitude * .pi / 180
        
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radians = atan2(y, x)
        return radians * 180 / .pi
    }
    
    private func getPlaneCoordinate(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D, progress: Double, isCurved: Bool = true) -> CLLocationCoordinate2D {
        let lat = start.latitude + (end.latitude - start.latitude) * progress
        let lng = start.longitude + (end.longitude - start.longitude) * progress
        let arcHeight = isCurved ? (sin(progress * .pi) * 1.5) : 0.0
        return CLLocationCoordinate2D(latitude: lat + arcHeight, longitude: lng)
    }
    
    private func getRouteCoordinates(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D, isCurved: Bool = true) -> [CLLocationCoordinate2D] {
        var coords: [CLLocationCoordinate2D] = []
        let steps = 40
        for i in 0...steps {
            let progress = Double(i) / Double(steps)
            coords.append(getPlaneCoordinate(from: start, to: end, progress: progress, isCurved: isCurved))
        }
        return coords
    }
    
    private func flightSummaryCard(_ flight: FlightStepInfo, type: StepType) -> some View {
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
                
                Text(formatDateString(flight.date))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
            }
            
            Text("\(flight.airline) \(flight.flightNumber)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            HStack(alignment: .center) {
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
            .padding(.vertical, 8)
            
            Divider()
            
            Text(flight.details)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .liquidGlassStyle(cornerRadius: 24, fillOpacity: 0.03, borderOpacity: 0.45)
    }
    
    private func flightDetailsSection(_ flight: FlightStepInfo, type: StepType) -> some View {
        let user = store.selectedUser ?? ""
        var flightFiles: [String] = []
        if let shared = flight.sharedFiles { flightFiles.append(contentsOf: shared) }
        if let profile = flight.profileFiles?[user] { flightFiles.append(profile) }
        
        var flightPasses: [String] = []
        if let walletShared = flight.walletPasses { flightPasses.append(contentsOf: walletShared) }
        if let walletProfile = flight.profileWalletPasses?[user] { flightPasses.append(walletProfile) }
        
        return VStack(alignment: .leading, spacing: 14) {
            if type == .flight {
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
            
            if type != .car && (!flightFiles.isEmpty || !flightPasses.isEmpty) {
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
                    .liquidGlassStyle(cornerRadius: 10, fillOpacity: 0.015, borderOpacity: 0.25)
                }
            }
        }
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
                
                Text("\(stay.days.count) Days")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
            }
            
            Text("Stay in \(stay.cityName)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            if let firstDay = stay.days.first, let lastDay = stay.days.last {
                Text("\(formatDateStringShort(firstDay.date)) - \(formatDateStringShort(lastDay.date))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
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
                    
                    Text(hotel.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(hotel.details)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
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
                    
                    ForEach(hotelFiles, id: \.self) { file in
                        if store.downloadedFiles.contains(file) {
                            Button {
                                if let url = store.getLocalFileURL(forFilename: file) {
                                    fileViewTitle = "Hotel Reservation"
                                    selectedFileToView = IdentifiableURL(url: url)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "doc.text.fill")
                                        .foregroundColor(.purple)
                                    Text("View Reservation PDF")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .font(.caption)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .liquidGlassStyle(cornerRadius: 10, fillOpacity: 0.015, borderOpacity: 0.2)
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
                                        .foregroundColor(.purple)
                                    Text("Download Reservation PDF")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.purple)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .liquidGlassStyle(cornerRadius: 10, fillOpacity: 0.015, borderOpacity: 0.2)
                            }
                        }
                    }
                }
                .padding(14)
                .liquidGlassStyle(cornerRadius: 16, fillOpacity: 0.01, borderOpacity: 0.3)
            }
        }
        .padding(20)
        .liquidGlassStyle(cornerRadius: 24, fillOpacity: 0.03, borderOpacity: 0.45)
    }
    
    private func stayDaysSection(_ stay: StayStepInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(stay.days) { day in
                VStack(alignment: .leading, spacing: 0) {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            if expandedDays.contains(day.id) {
                                expandedDays.remove(day.id)
                            } else {
                                expandedDays.insert(day.id)
                            }
                        }
                    } label: {
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
                            
                            Spacer()
                            
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
                    
                    if expandedDays.contains(day.id) {
                        Divider()
                            .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 14) {
                            if !day.description.isEmpty {
                                Text(day.description)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                                    .padding(.top, 12)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            if day.items.isEmpty {
                                Text("No activities planned. Free day!")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .italic()
                                    .padding(.horizontal)
                                    .padding(.bottom, 12)
                            } else {
                                VStack(spacing: 12) {
                                    ForEach(day.items) { item in
                                        activityItemCard(item, date: day.date)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 16)
                            }
                        }
                    }
                }
                .liquidGlassStyle(cornerRadius: 18, fillOpacity: 0.03, borderOpacity: 0.45)
                .padding(.bottom, 6)
                .onAppear {
                    if expandedDays.isEmpty, let firstDay = stay.days.first {
                        expandedDays.insert(firstDay.id)
                    }
                }
            }
        }
    }
    
    // MARK: - Activity Card Component
    
    private func activityItemCard(_ item: TripItem, date: String) -> some View {
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
            
            if item.type == .flight, let flightNo = item.flightNumber, !flightNo.isEmpty {
                Divider()
                FlightStatusTrackerView(flightNumber: flightNo, date: date, store: store)
            }
            
            if let place = item.mapPlace {
                Divider()
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(place.name)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            HStack(alignment: .top, spacing: 4) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.footnote)
                                Text(place.address)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        
                        Spacer()
                    }
                    
                    if let desc = place.description, !desc.isEmpty {
                        Text(desc)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    if let hours = place.openingHours, !hours.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Opening Hours")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(hours)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineSpacing(2)
                                .padding(.leading, 18)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    
                    HStack(spacing: 12) {
                        Button {
                            openInMaps(coordinate: place.coordinate, name: place.name)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                                    .font(.footnote)
                                Text("Directions")
                            }
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.blue)
                            .cornerRadius(8)
                        }
                        
                        if let phone = place.phoneNumber, let phoneURL = URL(string: "tel://\(phone.replacingOccurrences(of: " ", with: ""))") {
                            Button {
                                UIApplication.shared.open(phoneURL)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "phone.fill")
                                        .font(.footnote)
                                    Text("Call")
                                }
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .liquidGlassStyle(cornerRadius: 8, fillOpacity: 0.05, borderOpacity: 0.3)
                            }
                        }
                        
                        if let webString = place.websiteURL, let webURL = URL(string: webString) {
                            Link(destination: webURL) {
                                HStack(spacing: 6) {
                                    Image(systemName: "safari.fill")
                                        .font(.footnote)
                                    Text("Website")
                                }
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .liquidGlassStyle(cornerRadius: 8, fillOpacity: 0.05, borderOpacity: 0.3)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .liquidGlassStyle(cornerRadius: 14, fillOpacity: 0.015, borderOpacity: 0.3)
            }
            
            let user = store.selectedUser ?? ""
            let applicableFiles = item.getFiles(forUser: user)
            
            if !applicableFiles.isEmpty {
                Divider()
                
                if item.type == .flight || item.type == .train {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(applicableFiles, id: \.self) { file in
                            if store.downloadedFiles.contains(file) {
                                HStack(spacing: 8) {
                                    Button {
                                        if let url = store.getLocalFileURL(forFilename: file) {
                                            fileViewTitle = item.type == .flight ? "Boarding Pass" : "Train Ticket"
                                            selectedFileToView = IdentifiableURL(url: url)
                                        }
                                    } label: {
                                        HStack {
                                            Image(systemName: item.type == .flight ? "airplane" : "tram.fill")
                                                .foregroundColor(.accentColor)
                                            Text(item.type == .flight ? "View Boarding Pass" : "View Train Ticket")
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
                                        Text(item.type == .flight ? "Download Boarding Pass" : "Download Train Ticket")
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
                    }
                } else {
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
                                    
                                    Text(file.replacingOccurrences(of: "tickets/", with: "").replacingOccurrences(of: "passes/", with: ""))
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    if store.downloadedFiles.contains(file) {
                                        if let url = store.getLocalFileURL(forFilename: file) {
                                            HStack(spacing: 10) {
                                                ShareLink(item: url) {
                                                    Image(systemName: "square.and.arrow.up")
                                                        .font(.caption)
                                                }
                                                
                                                Button {
                                                    withAnimation(.easeInOut(duration: 0.25)) {
                                                        if expandedPDFs.contains(file) {
                                                            expandedPDFs.remove(file)
                                                        } else {
                                                            expandedPDFs.insert(file)
                                                        }
                                                    }
                                                } label: {
                                                    HStack(spacing: 3) {
                                                        Image(systemName: expandedPDFs.contains(file) ? "eye.slash" : "eye")
                                                            .font(.system(size: 10))
                                                        Text(expandedPDFs.contains(file) ? "Hide" : "Show")
                                                            .font(.caption)
                                                            .bold()
                                                    }
                                                }
                                                
                                                Button {
                                                    fileViewTitle = file.components(separatedBy: "/").last ?? "Ticket"
                                                    selectedFileToView = IdentifiableURL(url: url)
                                                } label: {
                                                    HStack(spacing: 3) {
                                                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                                                            .font(.system(size: 10))
                                                        Text("Open")
                                                            .font(.caption)
                                                            .bold()
                                                    }
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
                                
                                if expandedPDFs.contains(file), store.downloadedFiles.contains(file), let url = store.getLocalFileURL(forFilename: file) {
                                    PDFKitRepresentable(url: url)
                                        .frame(height: 320)
                                        .cornerRadius(10)
                                        .shadow(color: Color.black.opacity(0.08), radius: 5, x: 0, y: 3)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                                        )
                                        .padding(.top, 4)
                                        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
                                }
                            }
                            .padding(8)
                            .liquidGlassStyle(cornerRadius: 10, fillOpacity: 0.015, borderOpacity: 0.25)
                        }
                    }
                }
            }
            
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
                        .liquidGlassStyle(cornerRadius: 10, fillOpacity: 0.015, borderOpacity: 0.25)
                    }
                }
            }
            
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
                    .liquidGlassStyle(cornerRadius: 10, fillOpacity: 0.015, borderOpacity: 0.25)
                }
            }
        }
        .padding()
        .liquidGlassStyle(cornerRadius: 20, fillOpacity: 0.03, borderOpacity: 0.45)
    }
    
    // MARK: - Navigation Launcher
    
    private func openInMaps(coordinate: CLLocationCoordinate2D, name: String) {
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = name
        let launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
        mapItem.openInMaps(launchOptions: launchOptions)
    }
    
    // MARK: - Emojis Mapping
    
    private func getEmojiForStep(_ step: Step) -> String {
        let title = step.title.lowercased()
        let desc: String
        if step.type == .flight || step.type == .train, let flight = step.flightInfo {
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
        } else if title.contains("car") || title.contains("rental") || title.contains("drive") {
            return "🚗"
        } else if title.contains("train") || title.contains("transit") || title.contains("subway") || title.contains("rail") {
            return "🚇"
        } else if title.contains("city") || title.contains("york") || title.contains("citypass") {
            return "🗽"
        } else if title.contains("disney") || title.contains("universal") || title.contains("gardens") {
            return "🎢"
        } else if title.contains("space") || title.contains("ksc") || title.contains("kennedy") {
            return "🚀"
        } else {
            return "🇺🇸"
        }
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

// MARK: - Flight Status Tracker View

struct FlightStatusTrackerView: View {
    let flightNumber: String
    let date: String
    let store: TripStore
    
    @State private var status: FlightStatus? = nil
    @State private var isLoading = false
    @State private var errorOccurred = false
    
    private func isFlightDateNearToday() -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let flightDate = formatter.date(from: date) else { return false }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: flightDate)
        
        guard let dayDiff = calendar.dateComponents([.day], from: today, to: target).day else { return false }
        return abs(dayDiff) <= 1
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !isFlightDateNearToday() {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "clock.badge.exclamationmark")
                            .foregroundColor(.secondary)
                        Text("Scheduled for \(formatDateString(date))")
                            .font(.subheadline)
                            .fontWeight(.bold)
                    }
                    
                    Text("Live status, gate, and delay tracking will become available on the day of departure.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let flightradarURL = URL(string: "https://www.flightradar24.com/data/flights/\(flightNumber.lowercased())") {
                        Link(destination: flightradarURL) {
                            HStack {
                                Image(systemName: "safari")
                                Text("Check Schedule on FlightRadar24")
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
                .padding(10)
                .liquidGlassStyle(cornerRadius: 12, fillOpacity: 0.015, borderOpacity: 0.25)
            } else if isLoading {
                HStack {
                    ProgressView()
                        .padding(.trailing, 6)
                    Text("Fetching status for \(flightNumber)...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .center)
            } else if let fs = status {
                VStack(spacing: 12) {
                    // Status Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("FLIGHT STATUS")
                                .font(.caption2)
                                .fontWeight(.black)
                                .foregroundColor(.secondary)
                            Text(fs.flightNumber)
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                        
                        Spacer()
                        
                        // Status badge
                        Text(fs.status.uppercased())
                            .font(.caption2)
                            .fontWeight(.black)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(statusColor(fs.status))
                            .cornerRadius(6)
                    }
                    
                    Divider()
                    
                    // Route/Times Row
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(fs.departureCity)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            Text(fs.scheduledDeparture)
                                .font(.subheadline)
                                .fontWeight(.bold)
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 2) {
                            Image(systemName: "airplane")
                                .font(.system(size: 14))
                                .foregroundColor(.accentColor)
                            Rectangle()
                                .fill(Color.accentColor.opacity(0.3))
                                .frame(height: 1)
                                .frame(width: 40)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(fs.arrivalCity)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            Text(fs.estimatedDeparture)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(fs.delayMinutes > 0 ? .orange : .primary)
                        }
                    }
                    
                    if fs.delayMinutes > 0 {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("\(fs.delayMinutes) min delay")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    Divider()
                    
                    // Info Grid (2x2)
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                        GridRow {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("TERMINAL")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                                Text(fs.terminal)
                                    .font(.caption)
                                    .fontWeight(.bold)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("GATE")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                                Text(fs.gate)
                                    .font(.caption)
                                    .fontWeight(.bold)
                            }
                        }
                        GridRow {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("BAG CLAIM")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                                Text(fs.baggageClaim)
                                    .font(.caption)
                                    .fontWeight(.bold)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("AIRCRAFT")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                                Text(fs.aircraft)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .lineLimit(1)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // FlightRadar24 Link
                    if let flightradarURL = URL(string: "https://www.flightradar24.com/data/flights/\(fs.flightNumber.lowercased())") {
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

extension View {
    public func liquidGlassStyle(cornerRadius: CGFloat = 12, fillOpacity: Double = 0.03, borderOpacity: Double = 0.45) -> some View {
        self.modifier(LiquidGlassModifier(cornerRadius: cornerRadius, fillOpacity: fillOpacity, borderOpacity: borderOpacity))
    }
}
