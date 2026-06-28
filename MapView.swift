import SwiftUI
import MapKit

public struct MapView: View {
    enum CustomDetent: String, CaseIterable, Identifiable {
        case summary
        case half
        case full
        
        var id: String { self.rawValue }
    }

    struct LocalActivityMarker: Identifiable {
        let id: String
        let title: String
        let coordinate: CLLocationCoordinate2D
        let systemImage: String
        let color: Color
        let step: Step?
    }

    @ObservedObject var store: TripStore
    
    private var steps: [Step] {
        store.trip?.steps ?? []
    }
    
    @State private var position: MapCameraPosition = .automatic
    @State private var isShowingLocalStayDetails = false
    @State private var isShowingDayDetails = false
    @State private var currentDetent: CustomDetent = .summary
    @State private var dragOffset: CGFloat = 0
    
    public init(store: TripStore) {
        self.store = store
    }
    
    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $position, selection: $store.selectedStep) {
                    ForEach(getActiveMapMarkers()) { marker in
                        Marker(
                            marker.title,
                            systemImage: marker.systemImage,
                            coordinate: marker.coordinate
                        )
                        .tint(marker.color)
                        .tag(marker.step)
                    }
                    
                    let polylineCoordinates = getActivePolylineCoordinates()
                    if !polylineCoordinates.isEmpty {
                        MapPolyline(coordinates: polylineCoordinates)
                            .stroke(getActivePolylineColor(), lineWidth: 4)
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .ignoresSafeArea()
                
                // Custom Draggable Sheet positioned correctly at the bottom across iOS and macOS
                if let step = store.selectedStep {
                    VStack(spacing: 0) {
                        if step.type == .stay {
                            Capsule()
                                .fill(Color.secondary.opacity(0.5))
                                .frame(width: 36, height: 5)
                                .padding(.top, 8)
                                .padding(.bottom, 4)
                        } else {
                            Spacer()
                                .frame(height: 12)
                        }
                        
                        StaySheetContent(
                            step: step,
                            users: steps.first?.id != nil ? ["User"] : [],
                            isExpanded: currentDetent != .summary,
                            selectedDayId: store.selectedDayId,
                            onPrev: getPrevAction(for: step),
                            onNext: getNextAction(for: step),
                            openInMaps: {
                                openInMaps(coordinate: step.coordinate, name: getStepLocationName(step))
                            },
                            getStepLocationName: {
                                getStepLocationName(step)
                            },
                            onSelectDay: { day in
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    if store.selectedDayId == day.id {
                                        store.selectedDayId = nil
                                        isShowingDayDetails = false
                                        if let stayInfo = step.stayInfo {
                                            zoomToStay(stayInfo)
                                        }
                                    } else {
                                        store.selectedDayId = day.id
                                        isShowingDayDetails = true
                                        if let stayInfo = step.stayInfo {
                                            zoomToDay(day, stay: stayInfo)
                                        }
                                    }
                                }
                            }
                        )
                    }
                    .frame(maxWidth: 500)
                    .frame(height: {
                        guard step.type == .stay else { return 180 }
                        let base: CGFloat
                        switch currentDetent {
                        case .summary: base = 180
                        case .half: base = 450
                        case .full: base = 700
                        }
                        let target = base - dragOffset
                        return max(180, min(700, target))
                    }())
                    .liquidGlassStyle(cornerRadius: 24, fillOpacity: 0.08, borderOpacity: 0.35)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                guard step.type == .stay else { return }
                                dragOffset = value.translation.height
                            }
                            .onEnded { value in
                                guard step.type == .stay else { return }
                                
                                let dragDistance = value.translation.height
                                let predictedEnd = value.predictedEndTranslation.height
                                
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    if dragDistance < -80 || predictedEnd < -150 {
                                        // Dragging UP
                                        if currentDetent == .summary { currentDetent = .half }
                                        else if currentDetent == .half { currentDetent = .full }
                                    } else if dragDistance > 80 || predictedEnd > 150 {
                                        // Dragging DOWN
                                        if currentDetent == .full { currentDetent = .half }
                                        else if currentDetent == .half { currentDetent = .summary }
                                    }
                                    dragOffset = 0
                                }
                            }
                    )
                }
            }
            .navigationTitle("Route Map 🗺️")
            .navigationBarTitleDisplayMode(.inline)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: store.selectedStep)
            .onAppear {
                if store.selectedStep == nil, let first = steps.first {
                    store.selectedStep = first
                    zoomToStep(first, animated: false)
                } else if let selected = store.selectedStep {
                    zoomToStep(selected, animated: false)
                    if let dayId = store.selectedDayId, selected.type == .stay, let stay = selected.stayInfo, let day = stay.days.first(where: { $0.id == dayId }) {
                        currentDetent = .half
                        isShowingLocalStayDetails = true
                        isShowingDayDetails = true
                        zoomToDay(day, stay: stay)
                    }
                }
            }
            .onChange(of: store.selectedStep) { (oldStep: Step?, newStep: Step?) in
                guard let step = newStep else { return }
                currentDetent = .summary
                isShowingLocalStayDetails = false
                isShowingDayDetails = false
                if store.selectedDayId == nil {
                    store.selectedDayId = nil
                }
                zoomToStep(step)
            }
            .onChange(of: currentDetent) { (oldDetent: CustomDetent, newDetent: CustomDetent) in
                guard let step = store.selectedStep, step.type == .stay else { return }
                let showDetails = (newDetent == CustomDetent.half || newDetent == CustomDetent.full)
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                    isShowingLocalStayDetails = showDetails
                    if !showDetails {
                        isShowingDayDetails = false
                        store.selectedDayId = nil
                    }
                }
            }
            .onChange(of: isShowingLocalStayDetails) { (oldVal: Bool, newVal: Bool) in
                if newVal {
                    if let step = store.selectedStep, step.type == .stay, let stay = step.stayInfo, !isShowingDayDetails {
                        zoomToStay(stay)
                    }
                } else if let step = store.selectedStep {
                    zoomToStep(step)
                }
            }
        }
    }
    
    private func getActiveMapMarkers() -> [LocalActivityMarker] {
        if !isShowingLocalStayDetails && !isShowingDayDetails {
            // Whole Trip Mode: Show markers for all steps
            return steps.enumerated().map { index, step in
                LocalActivityMarker(
                    id: step.id,
                    title: "Step \(index + 1): \(step.title)",
                    coordinate: step.coordinate,
                    systemImage: step.type == .stay ? "house.fill" : (step.type == .flight ? "airplane" : (step.type == .train ? "tram.fill" : "car.fill")),
                    color: .blue,
                    step: step
                )
            }
        } else if let step = store.selectedStep, step.type == .stay, let stay = step.stayInfo {
            if let dayId = store.selectedDayId, let selectedDay = stay.days.first(where: { $0.id == dayId }) {
                // Day Specific Mode: Show hotel and this day's items only
                var markers: [LocalActivityMarker] = []
                if let hotelPlace = stay.hotel?.mapPlace {
                    markers.append(LocalActivityMarker(
                        id: stay.hotel?.id ?? "hotel",
                        title: hotelPlace.name,
                        coordinate: CLLocationCoordinate2D(latitude: hotelPlace.latitude, longitude: hotelPlace.longitude),
                        systemImage: "bed.double.fill",
                        color: .purple,
                        step: step
                    ))
                }
                
                for item in selectedDay.items {
                    if let place = item.mapPlace {
                        markers.append(LocalActivityMarker(
                            id: item.id,
                            title: item.title,
                            coordinate: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude),
                            systemImage: "mappin.and.ellipse",
                            color: .orange,
                            step: step
                        ))
                    }
                }
                return markers
            } else {
                // Stay Specific Mode: Show hotel and all day items
                var markers: [LocalActivityMarker] = []
                if let hotelPlace = stay.hotel?.mapPlace {
                    markers.append(LocalActivityMarker(
                        id: stay.hotel?.id ?? "hotel",
                        title: hotelPlace.name,
                        coordinate: CLLocationCoordinate2D(latitude: hotelPlace.latitude, longitude: hotelPlace.longitude),
                        systemImage: "bed.double.fill",
                        color: .purple,
                        step: step
                    ))
                }
                
                for day in stay.days {
                    for item in day.items {
                        if let place = item.mapPlace {
                            markers.append(LocalActivityMarker(
                                id: item.id,
                                title: item.title,
                                coordinate: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude),
                                systemImage: "mappin.and.ellipse",
                                color: .orange,
                                step: step
                            ))
                        }
                    }
                }
                return markers
            }
        }
        return []
    }
    
    private func getActivePolylineCoordinates() -> [CLLocationCoordinate2D] {
        if !isShowingLocalStayDetails && !isShowingDayDetails {
            return steps.map { $0.coordinate }
        } else if let step = store.selectedStep, step.type == .stay, let stay = step.stayInfo {
            if let dayId = store.selectedDayId, let selectedDay = stay.days.first(where: { $0.id == dayId }) {
                return getLocalDayCoordinates(selectedDay, stay: stay)
            } else {
                return getLocalStayCoordinates(stay)
            }
        }
        return []
    }
    
    private func getActivePolylineColor() -> Color {
        if !isShowingLocalStayDetails && !isShowingDayDetails {
            return Color.accentColor.opacity(0.6)
        } else {
            return Color.orange.opacity(0.6)
        }
    }

    private func getPrevAction(for step: Step) -> (() -> Void)? {
        guard let idx = steps.firstIndex(where: { $0.id == step.id }), idx > 0 else { return nil }
        return { store.selectedStep = steps[idx - 1] }
    }
    
    private func getNextAction(for step: Step) -> (() -> Void)? {
        guard let idx = steps.firstIndex(where: { $0.id == step.id }), idx < steps.count - 1 else { return nil }
        return { store.selectedStep = steps[idx + 1] }
    }
    
    private func getStepLocationName(_ step: Step) -> String {
        if step.type == .flight || step.type == .train || step.type == .car, let flight = step.flightInfo {
            return "\(flight.departureAirport.name) ➔ \(flight.arrivalAirport.name)"
        } else if step.type == .stay, let stay = step.stayInfo {
            return stay.cityName
        } else {
            return "Travel Step"
        }
    }
    
    // MARK: - Zooming & Map Camera
    
    private func zoomToStep(_ step: Step, animated: Bool = true) {
        let region: MKCoordinateRegion
        if step.type == .flight || step.type == .train || step.type == .car, let flight = step.flightInfo {
            let centerLat = (flight.departureAirport.latitude + flight.arrivalAirport.latitude) / 2
            let centerLng = (flight.departureAirport.longitude + flight.arrivalAirport.longitude) / 2
            let latDelta = abs(flight.departureAirport.latitude - flight.arrivalAirport.latitude) * 1.5 + 2.0
            let lngDelta = abs(flight.departureAirport.longitude - flight.arrivalAirport.longitude) * 1.5 + 2.0
            region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLng),
                span: MKCoordinateSpan(latitudeDelta: max(latDelta, 0.5), longitudeDelta: max(lngDelta, 0.5))
            )
        } else if step.type == .stay, let stay = step.stayInfo {
            let coord: CLLocationCoordinate2D
            if let hotelPlace = stay.hotel?.mapPlace {
                coord = CLLocationCoordinate2D(latitude: hotelPlace.latitude, longitude: hotelPlace.longitude)
            } else {
                coord = step.coordinate
            }
            region = MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.22, longitudeDelta: 0.22)
            )
        } else {
            return
        }
        
        if animated {
            withAnimation(.easeInOut(duration: 1.2)) {
                position = .region(region)
            }
        } else {
            position = .region(region)
        }
    }
    
    private func zoomToStay(_ stay: StayStepInfo) {
        let coords = getLocalStayCoordinates(stay)
        guard !coords.isEmpty else { return }
        
        let lats = coords.map { $0.latitude }
        let lngs = coords.map { $0.longitude }
        let minLat = lats.min() ?? 0
        let maxLat = lats.max() ?? 0
        let minLng = lngs.min() ?? 0
        let maxLng = lngs.max() ?? 0
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(maxLat - minLat, 0.015) * 1.5,
            longitudeDelta: max(maxLng - minLng, 0.015) * 1.5
        )
        
        withAnimation(.easeInOut(duration: 1.2)) {
            position = .region(MKCoordinateRegion(center: center, span: span))
        }
    }
    
    private func zoomToDay(_ day: DayInfo, stay: StayStepInfo) {
        let coords = getLocalDayCoordinates(day, stay: stay)
        guard !coords.isEmpty else { return }
        
        let lats = coords.map { $0.latitude }
        let lngs = coords.map { $0.longitude }
        let minLat = lats.min() ?? 0
        let maxLat = lats.max() ?? 0
        let minLng = lngs.min() ?? 0
        let maxLng = lngs.max() ?? 0
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(maxLat - minLat, 0.008) * 1.5,
            longitudeDelta: max(maxLng - minLng, 0.008) * 1.5
        )
        
        withAnimation(.easeInOut(duration: 1.2)) {
            position = .region(MKCoordinateRegion(center: center, span: span))
        }
    }
    
    private func getLocalStayCoordinates(_ stay: StayStepInfo) -> [CLLocationCoordinate2D] {
        var list: [CLLocationCoordinate2D] = []
        if let hotelPlace = stay.hotel?.mapPlace {
            list.append(CLLocationCoordinate2D(latitude: hotelPlace.latitude, longitude: hotelPlace.longitude))
        }
        for day in stay.days {
            for item in day.items {
                if let place = item.mapPlace {
                    list.append(CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude))
                }
            }
        }
        return list
    }
    
    private func getLocalDayCoordinates(_ day: DayInfo, stay: StayStepInfo) -> [CLLocationCoordinate2D] {
        var list: [CLLocationCoordinate2D] = []
        if let hotelPlace = stay.hotel?.mapPlace {
            list.append(CLLocationCoordinate2D(latitude: hotelPlace.latitude, longitude: hotelPlace.longitude))
        }
        for item in day.items {
            if let place = item.mapPlace {
                list.append(CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude))
            }
        }
        return list
    }
    
    private func openInMaps(coordinate: CLLocationCoordinate2D, name: String) {
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}

struct StaySheetContent: View {
    let step: Step
    let users: [String]
    let isExpanded: Bool
    let selectedDayId: String?
    
    let onPrev: (() -> Void)?
    let onNext: (() -> Void)?
    let openInMaps: () -> Void
    let getStepLocationName: () -> String
    let onSelectDay: (DayInfo) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Summary Header Card (Always visible)
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    Button {
                        onPrev?()
                    } label: {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                    }
                    .disabled(onPrev == nil)
                    .opacity(onPrev == nil ? 0.3 : 1.0)
                    
                    Spacer()
                    
                    VStack(spacing: 2) {
                        Text(step.type == .stay ? "STAY" : (step.type == .flight ? "FLIGHT" : (step.type == .train ? "TRAIN" : "ROAD TRIP")))
                            .font(.caption2)
                            .fontWeight(.black)
                            .foregroundColor(.secondary)
                        Text(step.title)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Button {
                        onNext?()
                    } label: {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                    }
                    .disabled(onNext == nil)
                    .opacity(onNext == nil ? 0.3 : 1.0)
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Location")
                            .font(.caption2)
                            .fontWeight(.black)
                            .foregroundColor(.secondary)
                        Text(getStepLocationName())
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Button(action: openInMaps) {
                        Label("Maps", systemImage: "map.fill")
                            .font(.caption)
                            .bold()
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(Color.accentColor.opacity(0.15))
                            .cornerRadius(8)
                    }
                }
                .padding(.top, 4)
            }
            .padding([.horizontal, .bottom])
            
            // Extended Scroll Details (Revealed when expanded upward)
            if isExpanded {
                Divider()
                
                if step.type != .stay {
                    // Transit Information details
                    VStack(alignment: .leading, spacing: 14) {
                        if let flight = step.flightInfo {
                            Text("Transit Details")
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Operator: \(flight.airline)")
                                Text("Route: \(flight.departureAirport.name) to \(flight.arrivalAirport.name)")
                                Text("Time: \(flight.departureTime) - \(flight.arrivalTime)")
                                Text("Description: \(flight.details)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.06))
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                } else if let stay = step.stayInfo {
                    // Stay information & day selector
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Accommodation details")
                                .font(.headline)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                                .padding(.top, 8)
                            
                            if let hotel = stay.hotel {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(hotel.title)
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                    Text(hotel.details)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.secondary.opacity(0.06))
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                            
                            HStack {
                                Text("Select Days")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                Spacer()
                                if selectedDayId != nil {
                                    Text("Showing selected day on map")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                        .bold()
                                }
                            }
                            .padding(.horizontal)
                            
                            ForEach(stay.days) { day in
                                Button {
                                    onSelectDay(day)
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text("Day \(day.dayNumber): \(day.title)")
                                                .font(.subheadline)
                                                .fontWeight(.bold)
                                                .foregroundColor(.primary)
                                            Spacer()
                                            Text(day.date)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        if !day.description.isEmpty {
                                            Text(day.description)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)
                                        }
                                        
                                        if !day.items.isEmpty {
                                            VStack(alignment: .leading, spacing: 6) {
                                                ForEach(day.items) { item in
                                                    HStack(spacing: 8) {
                                                        Image(systemName: item.type == .hotel ? "bed.double.fill" : "mappin.and.ellipse")
                                                            .font(.caption2)
                                                            .foregroundColor(.accentColor)
                                                        Text(item.title)
                                                            .font(.caption)
                                                            .foregroundColor(.primary)
                                                        Spacer()
                                                        Text(item.time)
                                                            .font(.caption2)
                                                            .foregroundColor(.secondary)
                                                    }
                                                    .padding(6)
                                                    .background(Color.secondary.opacity(0.08))
                                                    .cornerRadius(6)
                                                }
                                            }
                                            .padding(.top, 2)
                                        }
                                    }
                                    .padding()
                                    .background(selectedDayId == day.id ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.04))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selectedDayId == day.id ? Color.accentColor : Color.clear, lineWidth: 2)
                                    )
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
        }
    }
}
