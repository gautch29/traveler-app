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
    case train = "train"
    
    public var iconName: String {
        switch self {
        case .flight: return "airplane"
        case .hotel: return "house.fill"
        case .activity: return "ticket.fill"
        case .transit: return "car.fill"
        case .train: return "tram.fill"
        }
    }
}

public struct MapPlaceInfo: Codable, Hashable, Equatable {
    public let name: String
    public let address: String
    public let phoneNumber: String?
    public let websiteURL: String?
    public let latitude: Double
    public let longitude: Double
    public let openingHours: String?
    public let description: String?
    
    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
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
    public var flightNumber: String? // Optional flight code
    public var mapPlace: MapPlaceInfo? // Optional Apple Maps Place details
    
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

public struct FlightStatus: Codable, Equatable {
    public let flightNumber: String
    public let status: String
    public let gate: String
    public let terminal: String
    public let delayMinutes: Int
    public let scheduledDeparture: String
    public let estimatedDeparture: String
    public let aircraft: String
    public let departureCity: String
    public let arrivalCity: String
    public let baggageClaim: String
}


public enum StepType: String, Codable {
    case flight = "flight"
    case train = "train"
    case stay = "stay"
    case car = "car"
}

public struct DayInfo: Codable, Identifiable, Hashable, Equatable {
    public var id: String
    public var dayNumber: Int
    public var date: String
    public var title: String
    public var description: String
    public var items: [TripItem]
    
    public init(id: String = UUID().uuidString.lowercased(), dayNumber: Int, date: String, title: String, description: String, items: [TripItem]) {
        self.id = id
        self.dayNumber = dayNumber
        self.date = date
        self.title = title
        self.description = description
        self.items = items
    }
}

public struct StayStepInfo: Codable, Equatable {
    public var cityName: String
    public var hotel: TripItem?
    public var days: [DayInfo]
    
    public init(cityName: String, hotel: TripItem? = nil, days: [DayInfo] = []) {
        self.cityName = cityName
        self.hotel = hotel
        self.days = days
    }
}

public struct FlightStepInfo: Codable, Equatable {
    public var flightNumber: String
    public var airline: String
    public var departureAirport: LocationInfo
    public var arrivalAirport: LocationInfo
    public var departureTime: String
    public var arrivalTime: String
    public var date: String
    public var details: String
    public var sharedFiles: [String]?
    public var profileFiles: [String: String]?
    public var walletPasses: [String]?
    public var profileWalletPasses: [String: String]?
    
    public init(flightNumber: String, airline: String, departureAirport: LocationInfo, arrivalAirport: LocationInfo, departureTime: String, arrivalTime: String, date: String, details: String, sharedFiles: [String]? = nil, profileFiles: [String: String]? = nil, walletPasses: [String]? = nil, profileWalletPasses: [String: String]? = nil) {
        self.flightNumber = flightNumber
        self.airline = airline
        self.departureAirport = departureAirport
        self.arrivalAirport = arrivalAirport
        self.departureTime = departureTime
        self.arrivalTime = arrivalTime
        self.date = date
        self.details = details
        self.sharedFiles = sharedFiles
        self.profileFiles = profileFiles
        self.walletPasses = walletPasses
        self.profileWalletPasses = profileWalletPasses
    }
}

public struct Step: Codable, Identifiable, Hashable, Equatable {
    public var id: String
    public var type: StepType
    public var title: String
    public var date: String
    public var flightInfo: FlightStepInfo?
    public var stayInfo: StayStepInfo?
    
    public init(id: String = UUID().uuidString.lowercased(), type: StepType, title: String, date: String, flightInfo: FlightStepInfo? = nil, stayInfo: StayStepInfo? = nil) {
        self.id = id
        self.type = type
        self.title = title
        self.date = date
        self.flightInfo = flightInfo
        self.stayInfo = stayInfo
    }
    
    public var coordinate: CLLocationCoordinate2D {
        if type == .flight || type == .train || type == .car, let flight = flightInfo {
            return flight.departureAirport.coordinate
        } else if type == .stay, let stay = stayInfo, let hotelPlace = stay.hotel?.mapPlace {
            return CLLocationCoordinate2D(latitude: hotelPlace.latitude, longitude: hotelPlace.longitude)
        } else {
            return CLLocationCoordinate2D(latitude: 37.0902, longitude: -95.7129)
        }
    }
    
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
    public let location: LocationInfo?
    
    public init(id: UUID = UUID(), title: String, amount: Double, paidBy: String, splitAmong: [String], date: Date = Date(), location: LocationInfo? = nil) {
        self.id = id
        self.title = title
        self.amount = amount
        self.paidBy = paidBy
        self.splitAmong = splitAmong
        self.date = date
        self.location = location
    }
}
