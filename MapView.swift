import SwiftUI
import MapKit

public struct MapView: View {
    enum MapMode: String, CaseIterable, Identifiable {
        case wholeTrip = "Whole Trip"
        case stayDetails = "Stay Details"
        
        var id: String { self.rawValue }
    }

    struct LocalActivityMarker: Identifiable {
        let id: String
        let title: String
        let coordinate: CLLocationCoordinate2D
    }

    let steps: [Step]
    
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedStep: Step? = nil
    @State private var mapMode: MapMode = .wholeTrip
    
    public init(steps: [Step]) {
        self.steps = steps
    }
    
    public var body: some View {
        NavigationStack {
            Map(position: $position, selection: $selectedStep) {
                if mapMode == .wholeTrip {
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
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Map Mode", selection: $mapMode) {
                        ForEach(MapMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let step = selectedStep {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .center) {
                            // Back / Prev Button
                            Button {
                                if let idx = steps.firstIndex(where: { $0.id == step.id }), idx > 0 {
                                    selectedStep = steps[idx - 1]
                                }
                            } label: {
                                Image(systemName: "chevron.left.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.accentColor)
                            }
                            .disabled(steps.firstIndex(where: { $0.id == step.id }) == 0)
                            .opacity(steps.firstIndex(where: { $0.id == step.id }) == 0 ? 0.3 : 1.0)
                            
                            Spacer()
                            
                            // Day Tag & Navigator Title
                            if let idx = steps.firstIndex(where: { $0.id == step.id }) {
                                VStack(spacing: 2) {
                                    Text("Step \(idx + 1) of \(steps.count)")
                                        .font(.caption2)
                                        .fontWeight(.bold)
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
                            }
                            
                            Spacer()
                            
                            // Next Button
                            Button {
                                if let idx = steps.firstIndex(where: { $0.id == step.id }), idx < steps.count - 1 {
                                    selectedStep = steps[idx + 1]
                                }
                            } label: {
                                Image(systemName: "chevron.right.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.accentColor)
                            }
                            .disabled(steps.firstIndex(where: { $0.id == step.id }) == steps.count - 1)
                            .opacity(steps.firstIndex(where: { $0.id == step.id }) == steps.count - 1 ? 0.3 : 1.0)
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.2))
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(getStepLocationName(step))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            Button {
                                openInMaps(coordinate: step.coordinate, name: getStepLocationName(step))
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
                    .liquidGlassStyle(cornerRadius: 20, fillOpacity: 0.04, borderOpacity: 0.45)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
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
                    if step.type != .stay {
                        mapMode = .wholeTrip
                    }
                    
                    if mapMode == .stayDetails, let stay = step.stayInfo {
                        zoomToStay(stay)
                    } else {
                        zoomToStep(step)
                    }
                }
            }
            .onChange(of: mapMode) { _, newMode in
                if newMode == .stayDetails, let step = selectedStep, step.type == .stay, let stay = step.stayInfo {
                    zoomToStay(stay)
                } else if let step = selectedStep {
                    zoomToStep(step)
                }
            }
        }
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
