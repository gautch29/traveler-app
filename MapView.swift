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
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Day \(step.dayNumber)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentColor)
                                .cornerRadius(6)
                            
                            Spacer()
                            
                            Button {
                                selectedStep = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .imageScale(.large)
                            }
                        }
                        
                        Text(step.title)
                            .font(.headline)
                        
                        Text(step.location.name)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Divider()
                            .padding(.vertical, 4)
                        
                        HStack {
                            Button {
                                openInMaps(coordinate: step.location.coordinate, name: step.location.name)
                            } label: {
                                Label("Navigate", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                                    .font(.caption)
                                    .fontWeight(.bold)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.accentColor)
                            
                            Spacer()
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedStep)
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
