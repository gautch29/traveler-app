import SwiftUI
import MapKit

public struct MapView: View {
    let steps: [Step]
    
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedStep: Step? = nil
    
    public init(steps: [Step]) {
        self.steps = steps
    }
    
    public var body: some View {
        NavigationStack {
            Map(position: $position, selection: $selectedStep) {
                ForEach(steps) { step in
                    Marker(
                        "Day \(step.dayNumber): \(step.title)",
                        systemImage: "mappin.and.ellipse",
                        coordinate: step.location.coordinate
                    )
                    .tag(step)
                }
                
                // Draw route polyline connecting the points chronologically
                MapPolyline(coordinates: steps.map { $0.location.coordinate })
                    .stroke(Color.accentColor.opacity(0.6), lineWidth: 4)
            }
            .mapStyle(.standard(elevation: .realistic))
            .navigationTitle("Route Map 🗺️")
            .navigationBarTitleDisplayMode(.inline)
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
                            VStack(spacing: 2) {
                                Text("Day \(step.dayNumber) of \(steps.count)")
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
                                Text(step.location.name)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            Button {
                                openInMaps(coordinate: step.location.coordinate, name: step.location.name)
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
            .onChange(of: selectedStep) { newStep in
                if let step = newStep {
                    zoomToStep(step)
                }
            }
        }
    }
    
    private func zoomToStep(_ step: Step, animated: Bool = true) {
        let region = MKCoordinateRegion(
            center: step.location.coordinate,
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
    
    private func openInMaps(coordinate: CLLocationCoordinate2D, name: String) {
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}
