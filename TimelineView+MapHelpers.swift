import SwiftUI
import MapKit

extension TimelineView {
    func openInMaps(coordinate: CLLocationCoordinate2D, name: String) {
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = name
        let launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
        mapItem.openInMaps(launchOptions: launchOptions)
    }
    
    func getEmojiForStep(_ step: Step) -> String {
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
    
    func getRouteCoordinates(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D, isCurved: Bool) -> [CLLocationCoordinate2D] {
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
    
    func getPlaneCoordinate(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D, progress: Double, isCurved: Bool) -> CLLocationCoordinate2D {
        let lat = from.latitude + (to.latitude - from.latitude) * progress
        let lng = from.longitude + (to.longitude - from.longitude) * progress
        if !isCurved {
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        let curvature: Double = 2.0
        let offset = sin(progress * .pi) * curvature
        return CLLocationCoordinate2D(latitude: lat + offset, longitude: lng)
    }
    
    func getBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
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
    
    func startPlaneAnimation() {
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
