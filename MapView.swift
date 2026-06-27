import SwiftUI
import MapKit

public struct MapView: View {
    struct LocalActivityMarker: Identifiable {
        let id: String
        let title: String
        let coordinate: CLLocationCoordinate2D
    }

    let steps: [Step]
    
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedStep: Step? = nil
    @State private var isShowingLocalStayDetails = false
    @State private var activeDetent: PresentationDetent = .height(180)
    
    public init(steps: [Step]) {
        self.steps = steps
    }
    
    public var body: some View {
        NavigationStack {
            Map(position: $position, selection: $selectedStep) {
                if !isShowingLocalStayDetails {
                    ForEach(0..<steps.count, id: \.self) { index in
                        let step = steps[index]
                        Marker(
                            "Step \(index + 1): \(step.title)",
                            systemImage: step.type == .stay ? "house.fill" : (step.type == .flight ? "airplane" : "tram.fill"),
                            coordinate: step.coordinate
                        )
                        .tag(step)
                    }
                    
                    // Draw route polyline connecting the points chronologically
                    MapPolyline(coordinates: steps.map { $0.coordinate })
                        .stroke(Color.accentColor.opacity(0.6), lineWidth: 4)
                } else if let step = selectedStep, step.type == .stay, let stay = step.stayInfo {
                    // Stay Details Mode: show hotel and activity locations
                    if let hotelPlace = stay.hotel?.mapPlace {
                        Marker(
                            hotelPlace.name,
                            systemImage: "bed.double.fill",
                            coordinate: CLLocationCoordinate2D(latitude: hotelPlace.latitude, longitude: hotelPlace.longitude)
                        )
                        .tint(.purple)
                    }
                    
                    // Get all activities and plot them in a flat loop
                    ForEach(getLocalActivityMarkers(for: stay)) { marker in
                        Marker(
                            marker.title,
                            systemImage: "mappin.and.ellipse",
                            coordinate: marker.coordinate
                        )
                        .tint(.orange)
                    }
                    
                    // Draw polyline connecting stay items
                    let localCoordinates = getLocalStayCoordinates(stay)
                    if !localCoordinates.isEmpty {
                        MapPolyline(coordinates: localCoordinates)
                            .stroke(Color.orange.opacity(0.6), lineWidth: 4)
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .navigationTitle("Route Map 🗺️")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: .constant(true)) {
                if let step = selectedStep {
                    StaySheetContent(
                        step: step,
                        users: steps.first?.id != nil ? ["User"] : [], // Fallback users collection helper
                        isExpanded: isShowingLocalStayDetails,
                        onPrev: getPrevAction(for: step),
                        onNext: getNextAction(for: step),
                        openInMaps: {
                            openInMaps(coordinate: step.coordinate, name: getStepLocationName(step))
                        },
                        getStepLocationName: {
                            getStepLocationName(step)
                        }
                    )
                    .presentationDetents(step.type == .stay ? [.height(180), .medium, .large] : [.height(180)], selection: $activeDetent)
                    .presentationBackgroundInteraction(.enabled)
                    .presentationDragIndicator(.visible)
                    .interactiveDismissDisabled(true)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedStep)
            .onAppear {
                // Focus on the first step on startup
                if selectedStep == nil, let first = steps.first {
                    selectedStep = first
                    zoomToStep(first, animated: false)
                }
            }
            .onChange(of: selectedStep) { _, newStep in
                if let step = newStep {
                    activeDetent = .height(180)
                    isShowingLocalStayDetails = false
                    zoomToStep(step)
                }
            }
            .onChange(of: activeDetent) { _, newDetent in
                if let step = selectedStep, step.type == .stay, step.stayInfo != nil {
                    if newDetent == .medium || newDetent == .large {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                            isShowingLocalStayDetails = true
                        }
                    } else {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                            isShowingLocalStayDetails = false
                        }
                    }
                }
            }
            .onChange(of: isShowingLocalStayDetails) { _, newValue in
                if newValue, let step = selectedStep, step.type == .stay, let stay = step.stayInfo {
                    zoomToStay(stay)
                } else if let step = selectedStep {
                    zoomToStep(step)
                }
            }
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
        if step.type == .flight || step.type == .train, let flight = step.flightInfo {
            return "\(flight.departureAirport.name) ➔ \(flight.arrivalAirport.name)"
        } else if step.type == .stay, let stay = step.stayInfo {
            return stay.cityName
        } else {
            return "Travel Step"
        }
    }
    
    private func getLocalActivityMarkers(for stay: StayStepInfo) -> [LocalActivityMarker] {
        var markers: [LocalActivityMarker] = []
        for day in stay.days {
            for item in day.items {
                if let place = item.mapPlace {
                    markers.append(LocalActivityMarker(
                        id: item.id,
                        title: "Day \(day.dayNumber): \(item.title)",
                        coordinate: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
                    ))
                }
            }
        }
        return markers
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
    
    let onPrev: (() -> Void)?
    let onNext: (() -> Void)?
    let openInMaps: () -> Void
    let getStepLocationName: () -> String
    
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
                        Text(step.type == .stay ? "STAY" : (step.type == .flight ? "FLIGHT" : "TRAIN"))
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
                            Text("Swipe up to view days & activities 📍")
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
                        Text("Stays Itinerary")
                            .font(.headline)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                            .padding(.top, 10)
                        
                        ForEach(stay.days) { day in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Day \(day.dayNumber)")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color.blue)
                                        .cornerRadius(4)
                                    
                                    Text(day.title)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    
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
                            .background(Color.secondary.opacity(0.04))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
        }
    }
}
