import Foundation
import CoreLocation

public struct EmergencyNumber: Codable, Identifiable, Equatable {
    public var id: String { label + number }
    public let label: String
    public let number: String
}

public struct EmergencyInfo: Codable, Equatable {
    public let numbers: [EmergencyNumber]
    public let notes: String
}

public struct LocationInfo: Codable, Hashable, Equatable {
    public let name: String
    public let latitude: Double
    public let longitude: Double
    
    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

public enum TripItemType: String, Codable, CaseIterable {
    case flight = "flight"
    case hotel = "hotel"
    case activity = "activity"
    case transit = "transit"
    
    public var iconName: String {
        switch self {
        case .flight: return "airplane"
        case .hotel: return "house.fill"
        case .activity: return "ticket.fill"
        case .transit: return "car.fill"
        }
    }
}

public struct TripItem: Codable, Identifiable, Hashable, Equatable {
    public var id: String
    public var type: TripItemType
    public var title: String
    public var time: String
    public var details: String
    public var sharedFiles: [String]
    public var profileFiles: [String: String]? // Maps username to file name
    public var walletPasses: [String]? // Shared .pkpass files
    public var profileWalletPasses: [String: String]? // Maps username to personal .pkpass file
    public var websiteURL: String? // Optional website link
    
    // Helper to get applicable files for a user
    public func getFiles(forUser username: String) -> [String] {
        var files = sharedFiles
        if let userFile = profileFiles?[username] {
            files.append(userFile)
        }
        return files
    }
    
    // Helper to get applicable wallet passes for a user
    public func getWalletPasses(forUser username: String) -> [String] {
        var passes = [String]()
        if let shared = walletPasses {
            passes.append(contentsOf: shared)
        }
        if let userPass = profileWalletPasses?[username] {
            passes.append(userPass)
        }
        return passes
    }
}

public struct Step: Codable, Identifiable, Hashable, Equatable {
    public var id: String
    public var dayNumber: Int
    public var title: String
    public var date: String
    public var location: LocationInfo
    public var description: String
    public var items: [TripItem]
    
    public static func == (lhs: Step, rhs: Step) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

public struct Trip: Codable, Equatable {
    public let tripName: String
    public let startDate: String
    public let endDate: String
    public let users: [String]
    public let emergencyInfo: EmergencyInfo
    public let steps: [Step]
}

public struct Expense: Codable, Identifiable, Equatable {
    public let id: UUID
    public let title: String
    public let amount: Double
    public let paidBy: String
    public let splitAmong: [String]
    public let date: Date
    
    public init(id: UUID = UUID(), title: String, amount: Double, paidBy: String, splitAmong: [String], date: Date = Date()) {
        self.id = id
        self.title = title
        self.amount = amount
        self.paidBy = paidBy
        self.splitAmong = splitAmong
        self.date = date
    }
}
