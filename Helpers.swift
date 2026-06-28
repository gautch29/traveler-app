import Foundation
import PassKit

public func formatDateString(_ dateStr: String) -> String {
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

public func formatDateStringShort(_ dateStr: String) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    guard let date = formatter.date(from: dateStr) else { return dateStr }
    
    formatter.dateFormat = "MMM d"
    return formatter.string(from: date)
}

@MainActor
public func isValidPKPass(file: String, store: TripStore) -> Bool {
    guard let url = store.getLocalFileURL(forFilename: file) else { return false }
    guard let data = try? Data(contentsOf: url) else { return false }
    return (try? PKPass(data: data)) != nil
}

public struct StagedFile {
    public let localURL: URL
    public let originalFilename: String
    public let type: String // "ticket" or "pass"
}

public func parseTempURL(_ string: String) -> StagedFile? {
    guard string.hasPrefix("temp://") else { return nil }
    guard let url = URL(string: string) else { return nil }
    
    let pathComponents = url.pathComponents
    guard pathComponents.count >= 2 else { return nil }
    let filename = pathComponents[1]
    
    let uuid = url.host ?? ""
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("TravelerTemp")
        .appendingPathComponent(uuid)
    let localURL = tempDir.appendingPathComponent(filename)
    
    let typeString = URLComponents(string: string)?.queryItems?.first(where: { $0.name == "type" })?.value ?? "ticket"
    
    return StagedFile(localURL: localURL, originalFilename: filename, type: typeString)
}

public func createTempURL(uuid: String, filename: String, type: String) -> String {
    return "temp://\(uuid)/\(filename)?type=\(type)"
}

public func displayFilename(forPath path: String) -> String {
    if path.hasPrefix("temp://") {
        if let staged = parseTempURL(path) {
            return staged.originalFilename + " (Staged)"
        }
    }
    return path.components(separatedBy: "/").last ?? path
}

public func stageFile(selectedURL: URL, type: String) -> String? {
    let gotAccess = selectedURL.startAccessingSecurityScopedResource()
    defer {
        if gotAccess {
            selectedURL.stopAccessingSecurityScopedResource()
        }
    }
    
    do {
        let fileData = try Data(contentsOf: selectedURL)
        let filename = selectedURL.lastPathComponent
        let uuid = UUID().uuidString.lowercased()
        
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TravelerTemp")
            .appendingPathComponent(uuid)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        
        let localURL = tempDir.appendingPathComponent(filename)
        try fileData.write(to: localURL)
        
        return createTempURL(uuid: uuid, filename: filename, type: type)
    } catch {
        print("Failed to stage file: \(error)")
        return nil
    }
}

import MapKit
public func openInMaps(coordinate: CLLocationCoordinate2D, name: String) {
    let placemark = MKPlacemark(coordinate: coordinate)
    let mapItem = MKMapItem(placemark: placemark)
    mapItem.name = name
    let launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
    mapItem.openInMaps(launchOptions: launchOptions)
}
