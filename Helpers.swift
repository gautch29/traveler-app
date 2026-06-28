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
