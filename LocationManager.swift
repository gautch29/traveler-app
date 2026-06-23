import Foundation
import CoreLocation

@MainActor
public class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published public var location: CLLocation?
    @Published public var authorizationStatus: CLAuthorizationStatus?
    
    public override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        self.authorizationStatus = manager.authorizationStatus
    }
    
    public func requestLocation() {
        let status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.requestLocation()
        } else {
            print("Location authorization denied or restricted.")
        }
    }
    
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        self.authorizationStatus = manager.authorizationStatus
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        self.location = locations.last
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager did fail with error: \(error.localizedDescription)")
    }
}
