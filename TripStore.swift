import Foundation
import Combine

@MainActor
public class TripStore: ObservableObject {
    @Published public var trip: Trip?
    @Published public var selectedUser: String?
    @Published public var serverURLString: String
    @Published public var isSyncing = false
    @Published public var syncError: String?
    @Published public var downloadedFiles: Set<String> = []
    @Published public var downloadProgress: [String: Double] = [:]
    @Published public var expenses: [Expense] = []
    
    private let fileManager = FileManager.default
    private let tripKey = "traveler_saved_trip"
    private let userKey = "traveler_selected_user"
    private let serverURLKey = "traveler_server_url"
    private let expensesKey = "traveler_expenses"
    
    public init() {
        // Load defaults
        self.serverURLString = UserDefaults.standard.string(forKey: serverURLKey) ?? "http://localhost:8000/trip.json"
        self.selectedUser = UserDefaults.standard.string(forKey: userKey)
        
        loadLocalData()
        loadLocalExpenses()
        checkCachedFiles()
    }
    
    // MARK: - Local Data Storage
    
    private func loadLocalData() {
        if let data = UserDefaults.standard.data(forKey: tripKey) {
            do {
                let decoder = JSONDecoder()
                self.trip = try decoder.decode(Trip.self, from: data)
            } catch {
                print("Failed to decode saved trip: \(error)")
            }
        }
    }
    
    private func saveLocalData() {
        guard let trip = trip else { return }
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(trip)
            UserDefaults.standard.set(data, forKey: tripKey)
        } catch {
            print("Failed to encode and save trip: \(error)")
        }
    }
    
    private func loadLocalExpenses() {
        if let data = UserDefaults.standard.data(forKey: expensesKey) {
            do {
                let decoder = JSONDecoder()
                self.expenses = try decoder.decode([Expense].self, from: data)
            } catch {
                print("Failed to decode expenses: \(error)")
            }
        }
    }
    
    public func saveExpenses() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(expenses)
            UserDefaults.standard.set(data, forKey: expensesKey)
        } catch {
            print("Failed to encode and save expenses: \(error)")
        }
    }
    
    public func selectUser(_ username: String) {
        self.selectedUser = username
        UserDefaults.standard.set(username, forKey: userKey)
    }
    
    public func updateServerURL(_ urlString: String) {
        self.serverURLString = urlString
        UserDefaults.standard.set(urlString, forKey: serverURLKey)
    }
    
    // MARK: - Sync Logic
    
    public func sync() async {
        guard let url = URL(string: serverURLString) else {
            self.syncError = "Invalid server URL"
            return
        }
        
        self.isSyncing = true
        self.syncError = nil
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            
            let decoder = JSONDecoder()
            let fetchedTrip = try decoder.decode(Trip.self, from: data)
            
            // Success
            self.trip = fetchedTrip
            self.saveLocalData()
            
            // Auto-select user if the current selected user is not in the list
            if let current = selectedUser, !fetchedTrip.users.contains(current) {
                self.selectedUser = nil
                UserDefaults.standard.removeObject(forKey: userKey)
            }
            
            // Trigger pre-download of all applicable files
            await downloadAllFilesForCurrentConfig()
            
        } catch {
            self.syncError = "Sync failed: \(error.localizedDescription). Using offline cached data."
            print("Sync error: \(error)")
        }
        
        self.isSyncing = false
    }
    
    public func uploadTrip() async -> Bool {
        guard let trip = trip, let url = URL(string: serverURLString) else { return false }
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(trip)
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = data
            
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return false
            }
            return true
        } catch {
            print("Failed to upload trip: \(error)")
            return false
        }
    }
    
    // MARK: - Cache & PDF Downloads
    
    private var assetsDirectory: URL {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let assetsDir = paths[0].appendingPathComponent("trip_assets", isDirectory: true)
        if !fileManager.fileExists(atPath: assetsDir.path) {
            try? fileManager.createDirectory(at: assetsDir, withIntermediateDirectories: true, attributes: nil)
        }
        return assetsDir
    }
    
    private func localURL(forFilename filename: String) -> URL {
        let safeName = filename.replacingOccurrences(of: "/", with: "_")
        return assetsDirectory.appendingPathComponent(safeName)
    }
    
    public func getLocalFileURL(forFilename filename: String) -> URL? {
        let url = localURL(forFilename: filename)
        if fileManager.fileExists(atPath: url.path) {
            return url
        }
        return nil
    }
    
    public func checkCachedFiles() {
        guard let trip = trip else { return }
        var cached = Set<String>()
        
        let allFiles = getAllReferencedFiles(forTrip: trip)
        for file in allFiles {
            let localPath = localURL(forFilename: file).path
            if fileManager.fileExists(atPath: localPath) {
                cached.insert(file)
            }
        }
        
        self.downloadedFiles = cached
    }
    
    private func getAllReferencedFiles(forTrip trip: Trip) -> Set<String> {
        var files = Set<String>()
        for step in trip.steps {
            for item in step.items {
                files.formUnion(item.sharedFiles)
                if let profileFiles = item.profileFiles {
                    for (_, file) in profileFiles {
                        files.insert(file)
                    }
                }
                if let walletShared = item.walletPasses {
                    files.formUnion(walletShared)
                }
                if let walletProfile = item.profileWalletPasses {
                    for (_, file) in walletProfile {
                        files.insert(file)
                    }
                }
            }
        }
        return files
    }
    
    public func downloadAllFilesForCurrentConfig() async {
        guard let trip = trip else { return }
        
        // Find files we actually need (shared files + files belonging to the selected user)
        var filesToDownload = Set<String>()
        let user = selectedUser ?? ""
        
        for step in trip.steps {
            for item in step.items {
                filesToDownload.formUnion(item.sharedFiles)
                if let profileFile = item.profileFiles?[user] {
                    filesToDownload.insert(profileFile)
                }
                if let walletShared = item.walletPasses {
                    filesToDownload.formUnion(walletShared)
                }
                if let walletProfile = item.profileWalletPasses?[user] {
                    filesToDownload.insert(walletProfile)
                }
            }
        }
        
        guard let tripURL = URL(string: serverURLString) else { return }
        let baseURL = tripURL.deletingLastPathComponent()
        
        for file in filesToDownload {
            if downloadedFiles.contains(file) { continue }
            
            // Build absolute file URL on server
            // e.g. base = "http://localhost:8000/", file = "tickets/ticket_gauthier.pdf"
            // -> "http://localhost:8000/tickets/ticket_gauthier.pdf"
            let remoteURL: URL
            if file.contains(":") {
                // If it's already an absolute URL
                guard let u = URL(string: file) else { continue }
                remoteURL = u
            } else {
                remoteURL = baseURL.appendingPathComponent(file)
            }
            
            do {
                try await downloadFile(from: remoteURL, originalFilename: file)
            } catch {
                print("Failed to download \(file): \(error)")
            }
        }
    }
    
    public func downloadFile(from url: URL, originalFilename: String) async throws {
        let destination = localURL(forFilename: originalFilename)
        
        // Download using URLSession
        let (tempURL, _) = try await URLSession.shared.download(from: url)
        
        // Remove existing if any
        if fileManager.fileExists(atPath: destination.path) {
            try? fileManager.removeItem(at: destination)
        }
        
        // Move to persistent location
        try fileManager.moveItem(at: tempURL, to: destination)
        
        // Update state
        self.downloadedFiles.insert(originalFilename)
    }
    
    public func clearCache() {
        let path = assetsDirectory.path
        if let files = try? fileManager.contentsOfDirectory(atPath: path) {
            for file in files {
                try? fileManager.removeItem(atPath: (path as NSString).appendingPathComponent(file))
            }
        }
        self.downloadedFiles.removeAll()
        self.downloadProgress.removeAll()
    }
    
    // MARK: - Expense Operations
    
    public func addExpense(title: String, amount: Double, paidBy: String, splitAmong: [String]) {
        let expense = Expense(title: title, amount: amount, paidBy: paidBy, splitAmong: splitAmong)
        expenses.append(expense)
        saveExpenses()
    }
    
    public func deleteExpense(at offsets: IndexSet) {
        expenses.remove(atOffsets: offsets)
        saveExpenses()
    }
    
    // MARK: - Debt Settlement Calculations
    
    public struct Debt: Identifiable, Equatable {
        public var id: String { from + "->" + to + ":" + String(amount) }
        public let from: String
        public let to: String
        public let amount: Double
    }
    
    public func calculateBalances() -> [String: Double] {
        guard let trip = trip else { return [:] }
        var balances = [String: Double]()
        
        // Initialize all users with 0
        for user in trip.users {
            balances[user] = 0.0
        }
        
        // Calculate paid and split amounts
        for expense in expenses {
            let amount = expense.amount
            let paidBy = expense.paidBy
            let splitCount = Double(expense.splitAmong.count)
            
            if splitCount > 0 {
                let share = amount / splitCount
                
                // Payer gets credited the amount they paid
                balances[paidBy, default: 0.0] += amount
                
                // Everyone in splitAmong owes their share
                for user in expense.splitAmong {
                    balances[user, default: 0.0] -= share
                }
            }
        }
        
        return balances
    }
    
    public func calculateSettlements() -> [Debt] {
        let balances = calculateBalances()
        var debtors = [(name: String, amount: Double)]()
        var creditors = [(name: String, amount: Double)]()
        
        for (user, bal) in balances {
            // Use small tolerance to avoid floating point precision issues
            if bal < -0.01 {
                debtors.append((user, abs(bal)))
            } else if bal > 0.01 {
                creditors.append((user, bal))
            }
        }
        
        // Sort both descending
        debtors.sort(by: { $0.amount > $1.amount })
        creditors.sort(by: { $0.amount > $1.amount })
        
        var settlements = [Debt]()
        
        var dIdx = 0
        var cIdx = 0
        
        while dIdx < debtors.count && cIdx < creditors.count {
            let debtor = debtors[dIdx]
            let creditor = creditors[cIdx]
            
            let settlementAmount = min(debtor.amount, creditor.amount)
            if settlementAmount > 0.01 {
                settlements.append(Debt(from: debtor.name, to: creditor.name, amount: settlementAmount))
            }
            
            debtors[dIdx].amount -= settlementAmount
            creditors[cIdx].amount -= settlementAmount
            
            if debtors[dIdx].amount < 0.01 {
                dIdx += 1
            }
            if creditors[cIdx].amount < 0.01 {
                cIdx += 1
            }
        }
        
        return settlements
    }
}
