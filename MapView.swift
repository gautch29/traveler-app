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

    let steps: [Step]
    
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedStep: Step? = nil
    @State private var isShowingLocalStayDetails = false
    @State private var isShowingDayDetails = false
    @State private var selectedDayId: String? = nil
    @State private var currentDetent: CustomDetent = .summary
    
    public init(steps: [Step]) {
        self.steps = steps
    }
    
    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $position, selection: $selectedStep) {
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
                if let step = selectedStep {
                    VStack(spacing: 0) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.5))
                            .frame(width: 36, height: 5)
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                        
                        StaySheetContent(
                            step: step,
                            users: steps.first?.id != nil ? ["User"] : [],
                            isExpanded: currentDetent != .summary,
                            selectedDayId: selectedDayId,
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
                                    if selectedDayId == day.id {
                                        selectedDayId = nil
                                        isShowingDayDetails = false
                                        if let stayInfo = step.stayInfo {
                                            zoomToStay(stayInfo)
                                        }
                                    } else {
                                        selectedDayId = day.id
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
                    .frame(height: currentDetent == .summary ? 180 : (currentDetent == .half ? 450 : 700))
                    .background(
                        Color(.systemBackground)
                            .opacity(0.85)
                            .background(Material.regularMaterial)
                    )
                    .cornerRadius(24)
                    .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: -2)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                guard step.type == .stay else { return }
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    if value.translation.height < -40 {
                                        if currentDetent == .summary { currentDetent = .half }
                                        else if currentDetent == .half { currentDetent = .full }
                                    } else if value.translation.height > 40 {
                                        if currentDetent == .full { currentDetent = .half }
                                        else if currentDetent == .half { currentDetent = .summary }
                                    }
                                }
                            }
                    )
                }
            }
            .navigationTitle("Route Map 🗺️")
            .navigationBarTitleDisplayMode(.inline)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedStep)
            .onAppear {
                // Focus on the first step on startup
                if selectedStep == nil, let first = steps.first {
                    selectedStep = first
                    zoomToStep(first, animated: false)
                }
            }
            .onChange(of: selectedStep) { (oldStep: Step?, newStep: Step?) in
                guard let step = newStep else { return }
                currentDetent = .summary
                isShowingLocalStayDetails = false
                isShowingDayDetails = false
                selectedDayId = nil
                zoomToStep(step)
            }
            .onChange(of: currentDetent) { (oldDetent: CustomDetent, newDetent: CustomDetent) in
                guard let step = selectedStep, step.type == .stay else { return }
                let showDetails = (newDetent == CustomDetent.half || newDetent == CustomDetent.full)
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                    isShowingLocalStayDetails = showDetails
                    if !showDetails {
                        isShowingDayDetails = false
                        selectedDayId = nil
                    }
                }
            }
            .onChange(of: isShowingLocalStayDetails) { (oldVal: Bool, newVal: Bool) in
                if newVal {
                    if let step = selectedStep, step.type == .stay, let stay = step.stayInfo, !isShowingDayDetails {
                        zoomToStay(stay)
                    }
                } else if let step = selectedStep {
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
        } else if let step = selectedStep, step.type == .stay, let stay = step.stayInfo {
            if let dayId = selectedDayId, let selectedDay = stay.days.first(where: { $0.id == dayId }) {
                // Day Specific Mode: Show hotel and this day's items only
                var markers: [LocalActivityMarker] = []
                if let hotelPlace = stay.hotel?.mapPlace {
                    markers.append(LocalActivityMarker(
                        id: stay.hotel?.id ?? "hotel",
                        title: hotelPlace.name,
                        coordinate: CLLocationCoordinate2D(latitude: hotelPlace.latitude, longitude: hotelPlace.longitude),
                        systemImage: "bed.double.fill",
                        color: .purple,
                        step: nil
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
                            step: nil
                        ))
                    }
                }
                return markers
            } else {
                // Stay Details Mode: Show hotel and all activities
                var markers: [LocalActivityMarker] = []
                if let hotelPlace = stay.hotel?.mapPlace {
                    markers.append(LocalActivityMarker(
                        id: stay.hotel?.id ?? "hotel",
                        title: hotelPlace.name,
                        coordinate: CLLocationCoordinate2D(latitude: hotelPlace.latitude, longitude: hotelPlace.longitude),
                        systemImage: "bed.double.fill",
                        color: .purple,
                        step: nil
                    ))
                }
                for day in stay.days {
                    for item in day.items {
                        if let place = item.mapPlace {
                            markers.append(LocalActivityMarker(
                                id: item.id,
                                title: "Day \(day.dayNumber): \(item.title)",
                                coordinate: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude),
                                systemImage: "mappin.and.ellipse",
                                color: .orange,
                                step: nil
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
        } else if let step = selectedStep, step.type == .stay, let stay = step.stayInfo {
            if let dayId = selectedDayId, let selectedDay = stay.days.first(where: { $0.id == dayId }) {
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
        return { selectedStep = steps[idx - 1] }
    }
    
    private func getNextAction(for step: Step) -> (() -> Void)? {
        guard let idx = steps.firstIndex(where: { $0.id == step.id }), idx < steps.count - 1 else { return nil }
        return { selectedStep = steps[idx + 1] }
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
    
    private func getLocalStayCoordinates(_ stay: StayStepInfo) -> [CLLocationCoordinate2D] {
        var coords: [CLLocationCoordinate2D] = []
        if let hotelPlace = stay.hotel?.mapPlace {
            coords.append(CLLocationCoordinate2D(latitude: hotelPlace.latitude, longitude: hotelPlace.longitude))
        }
        for day in stay.days {
            for item in day.items {
                if let place = item.mapPlace {
                    coords.append(CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude))
                }
            }
        }
        if let hotelPlace = stay.hotel?.mapPlace, coords.count > 1 {
            coords.append(CLLocationCoordinate2D(latitude: hotelPlace.latitude, longitude: hotelPlace.longitude))
        }
        return coords
    }
    
    private func getLocalDayCoordinates(_ day: DayInfo, stay: StayStepInfo) -> [CLLocationCoordinate2D] {
        var coords: [CLLocationCoordinate2D] = []
        if let hotelPlace = stay.hotel?.mapPlace {
            coords.append(CLLocationCoordinate2D(latitude: hotelPlace.latitude, longitude: hotelPlace.longitude))
        }
        for item in day.items {
            if let place = item.mapPlace {
                coords.append(CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude))
            }
        }
        if let hotelPlace = stay.hotel?.mapPlace, coords.count > 1 {
            coords.append(CLLocationCoordinate2D(latitude: hotelPlace.latitude, longitude: hotelPlace.longitude))
        }
        return coords
    }
    
    private func zoomToStep(_ step: Step, animated: Bool = true) {
        let region = MKCoordinateRegion(
            center: step.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.18, longitudeDelta: 0.18)
        )
        if animated {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.82)) {
                position = .region(region)
            }
        } else {
            position = .region(region)
        }
    }
    
    private func zoomToStay(_ stay: StayStepInfo) {
        let coords = getLocalStayCoordinates(stay)
        guard !coords.isEmpty else {
            zoomToCoordinate(getCenterCoordinate(forCityName: stay.cityName))
            return
        }
        let lats = coords.map { $0.latitude }
        let lns = coords.map { $0.longitude }
        let minLat = lats.min() ?? 0.0
        let maxLat = lats.max() ?? 0.0
        let minLng = lns.min() ?? 0.0
        let maxLng = lns.max() ?? 0.0
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.5, 0.08),
            longitudeDelta: max((maxLng - minLng) * 1.5, 0.08)
        )
        withAnimation(.spring(response: 0.8, dampingFraction: 0.82)) {
            position = .region(MKCoordinateRegion(center: center, span: span))
        }
    }
    
    private func zoomToDay(_ day: DayInfo, stay: StayStepInfo) {
        let coords = getLocalDayCoordinates(day, stay: stay)
        guard !coords.isEmpty else { return }
        let lats = coords.map { $0.latitude }
        let lns = coords.map { $0.longitude }
        let minLat = lats.min() ?? 0.0
        let maxLat = lats.max() ?? 0.0
        let minLng = lns.min() ?? 0.0
        let maxLng = lns.max() ?? 0.0
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.5, 0.04),
            longitudeDelta: max((maxLng - minLng) * 1.5, 0.04)
        )
        withAnimation(.spring(response: 0.8, dampingFraction: 0.82)) {
            position = .region(MKCoordinateRegion(center: center, span: span))
        }
    }
    
    private func zoomToCoordinate(_ coord: CLLocationCoordinate2D) {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.82)) {
            position = .region(MKCoordinateRegion(center: coord, span: MKCoordinateSpan(latitudeDelta: 0.18, longitudeDelta: 0.18)))
        }
    }
    
    private func getCenterCoordinate(forCityName city: String) -> CLLocationCoordinate2D {
        let name = city.lowercased()
        if name.contains("new york") || name.contains("nyc") {
            return CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        } else if name.contains("washington") || name.contains("dc") {
            return CLLocationCoordinate2D(latitude: 38.9072, longitude: -77.0369)
        } else if name.contains("orlando") {
            return CLLocationCoordinate2D(latitude: 28.5383, longitude: -81.3792)
        } else if name.contains("miami") {
            return CLLocationCoordinate2D(latitude: 25.7617, longitude: -80.1918)
        } else if name.contains("key west") {
            return CLLocationCoordinate2D(latitude: 24.5551, longitude: -81.7800)
        } else if name.contains("paris") {
            return CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522)
        } else {
            return CLLocationCoordinate2D(latitude: 37.0902, longitude: -95.7129)
        }
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
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.15))
                            .cornerRadius(6)
                        
                        Text(step.title)
                            .font(.subheadline)
                            .fontWeight(.bold)
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
                
                Divider()
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(getStepLocationName())
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        if step.type == .stay && !isExpanded {
                            Text("Drag up to view days & activities 📍")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button {
                        openInMaps()
                    } label: {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(color: Color.blue.opacity(0.3), radius: 3, x: 0, y: 1.5)
                    }
                }
            }
            .padding()
            
            // Revealed Days List (Only visible if expanded)
            if isExpanded, step.type == .stay, let stay = step.stayInfo {
                Divider()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Stays Itinerary")
                                .font(.headline)
                                .fontWeight(.bold)
                            Spacer()
                            if selectedDayId != nil {
                                Text("Showing selected day on map")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                    .fontWeight(.bold)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                        
                        ForEach(stay.days) { day in
                            Button {
                                onSelectDay(day)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("Day \(day.dayNumber)")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(selectedDayId == day.id ? Color.orange : Color.blue)
                                            .cornerRadius(4)
                                        
                                        Text(day.title)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
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
