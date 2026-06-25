import Foundation
import Combine

class SelfSignedSessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if let serverTrust = challenge.protectionSpace.serverTrust {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
                return
            }
        }
        completionHandler(.performDefaultHandling, nil)
    }
}

@MainActor
public class TripStore: ObservableObject {
    @Published public var trip: Trip?
    @Published public var selectedUser: String?
    @Published public var serverURLString: String
    @Published public var serverToken: String
    @Published public var isSyncing = false
    @Published public var syncError: String?
    @Published public var downloadedFiles: Set<String> = []
    @Published public var downloadProgress: [String: Double] = [:]
    @Published public var expenses: [Expense] = []
    
    private let fileManager = FileManager.default
    private let tripKey = "traveler_saved_trip"
    private let userKey = "traveler_selected_user"
    private let serverURLKey = "traveler_server_url"
    private let serverTokenKey = "traveler_server_token"
    private let expensesKey = "traveler_expenses"
    private var session: URLSession!
    
    public init() {
        // Load defaults
        self.serverToken = UserDefaults.standard.string(forKey: serverTokenKey) ?? "traveler_secret_token_2026"
        self.serverURLString = UserDefaults.standard.string(forKey: serverURLKey) ?? "https://usa.gautch.fr/trip.json"
        self.selectedUser = UserDefaults.standard.string(forKey: userKey)
        
        self.session = URLSession(configuration: .default, delegate: SelfSignedSessionDelegate(), delegateQueue: nil)
        
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
    
    public func fetchExpenses() async {
        guard let tripURL = URL(string: serverURLString) else { return }
        let baseURL = tripURL.deletingLastPathComponent()
        let expensesURL = baseURL.appendingPathComponent("expenses.json")
        
        var request = URLRequest(url: expensesURL)
        if !serverToken.isEmpty {
            request.setValue("Bearer \(serverToken)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, response) = try await self.session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return }
            
            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                let fetchedExpenses = try decoder.decode([Expense].self, from: data)
                self.expenses = fetchedExpenses
                
                // Save locally too as offline fallback
                do {
                    let encoder = JSONEncoder()
                    let localData = try encoder.encode(fetchedExpenses)
                    UserDefaults.standard.set(localData, forKey: expensesKey)
                } catch {}
            } else if httpResponse.statusCode == 404 {
                print("No expenses found on server (404).")
            }
        } catch {
            print("Failed to fetch expenses: \(error)")
        }
    }
    
    public func uploadExpenses() async -> Bool {
        guard let tripURL = URL(string: serverURLString) else { return false }
        let baseURL = tripURL.deletingLastPathComponent()
        let expensesURL = baseURL.appendingPathComponent("expenses.json")
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(expenses)
            
            var request = URLRequest(url: expensesURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if !serverToken.isEmpty {
                request.setValue("Bearer \(serverToken)", forHTTPHeaderField: "Authorization")
            }
            request.httpBody = data
            
            let (_, response) = try await self.session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return false
            }
            return true
        } catch {
            print("Failed to upload expenses: \(error)")
            return false
        }
    }
    
    public func fetchFlightStatus(for flightNumber: String) async -> FlightStatus? {
        guard let tripURL = URL(string: serverURLString) else { return nil }
        let baseURL = tripURL.deletingLastPathComponent()
        
        var components = URLComponents(url: baseURL.appendingPathComponent("flight-status"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "flight", value: flightNumber)]
        
        guard let url = components?.url else { return nil }
        
        var request = URLRequest(url: url)
        if !serverToken.isEmpty {
            request.setValue("Bearer \(serverToken)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, response) = try await self.session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }
            let decoder = JSONDecoder()
            return try decoder.decode(FlightStatus.self, from: data)
        } catch {
            print("Failed to fetch flight status for \(flightNumber): \(error)")
            return nil
        }
    }
    
    public func generateAISummary(title: String, locationName: String, items: [TripItem]) async -> String? {
        guard let tripURL = URL(string: serverURLString) else { return nil }
        let baseURL = tripURL.deletingLastPathComponent()
        let summaryURL = baseURL.appendingPathComponent("generate-summary")
        
        struct GeneratePayload: Codable {
            let title: String
            let locationName: String
            let items: [TripItem]
        }
        
        let payload = GeneratePayload(title: title, locationName: locationName, items: items)
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(payload)
            
            var request = URLRequest(url: summaryURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if !serverToken.isEmpty {
                request.setValue("Bearer \(serverToken)", forHTTPHeaderField: "Authorization")
            }
            request.httpBody = data
            
            let (responseData, response) = try await self.session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }
            
            struct ResponsePayload: Codable {
                let summary: String
            }
            
            let decoder = JSONDecoder()
            let result = try decoder.decode(ResponsePayload.self, from: responseData)
            return result.summary
        } catch {
            print("Failed to generate AI summary: \(error)")
            return nil
        }
    }
    
    public func uploadFile(data: Data, filename: String) async -> Bool {
        guard let tripURL = URL(string: serverURLString) else { return false }
        let baseURL = tripURL.deletingLastPathComponent()
        let uploadURL = baseURL.appendingPathComponent("upload")
        
        do {
            var request = URLRequest(url: uploadURL)
            request.httpMethod = "POST"
            request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            request.setValue(filename, forHTTPHeaderField: "X-Filename")
            if !serverToken.isEmpty {
                request.setValue("Bearer \(serverToken)", forHTTPHeaderField: "Authorization")
            }
            request.httpBody = data
            
            let (_, response) = try await self.session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return false
            }
            
            // Instantly register and cache locally
            self.downloadedFiles.insert(filename)
            let dest = localURL(forFilename: filename)
            try? data.write(to: dest)
            
            return true
        } catch {
            print("Failed to upload file \(filename): \(error)")
            return false
        }
    }
    
    public func fetchServerFiles() async -> [String] {
        guard let tripURL = URL(string: serverURLString) else { return [] }
        let baseURL = tripURL.deletingLastPathComponent()
        let listURL = baseURL.appendingPathComponent("list-files")
        
        var request = URLRequest(url: listURL)
        if !serverToken.isEmpty {
            request.setValue("Bearer \(serverToken)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, response) = try await self.session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return []
            }
            
            let decoder = JSONDecoder()
            let files = try decoder.decode([String].self, from: data)
            return files.sorted()
        } catch {
            print("Failed to fetch server files: \(error)")
            return []
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
    
    public func updateServerToken(_ token: String) {
        self.serverToken = token
        UserDefaults.standard.set(token, forKey: serverTokenKey)
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
            var request = URLRequest(url: url)
            if !serverToken.isEmpty {
                request.setValue("Bearer \(serverToken)", forHTTPHeaderField: "Authorization")
            }
            let (data, response) = try await self.session.data(for: request)
            
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
            
            // Sync expenses from server
            await fetchExpenses()
            
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
            if !serverToken.isEmpty {
                request.setValue("Bearer \(serverToken)", forHTTPHeaderField: "Authorization")
            }
            request.httpBody = data
            
            let (_, response) = try await self.session.data(for: request)
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
        
        // Download using custom session
        var request = URLRequest(url: url)
        if !serverToken.isEmpty {
            request.setValue("Bearer \(serverToken)", forHTTPHeaderField: "Authorization")
        }
        let (tempURL, _) = try await self.session.download(for: request)
        
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
    
    public func addExpense(title: String, amount: Double, paidBy: String, splitAmong: [String], location: LocationInfo?) {
        let expense = Expense(title: title, amount: amount, paidBy: paidBy, splitAmong: splitAmong, location: location)
        
        // Optimistically update local array and cache
        expenses.append(expense)
        saveExpenses()
        
        Task {
            // Pull the latest expenses from the server to merge conflicts
            await fetchExpenses()
            
            // Append if not already present
            if !expenses.contains(where: { $0.id == expense.id }) {
                expenses.append(expense)
                saveExpenses()
            }
            _ = await uploadExpenses()
        }
    }
    
    public func deleteExpense(at offsets: IndexSet) {
        // Collect exact IDs to delete before mutating the local array
        let idsToDelete = offsets.map { expenses[$0].id }
        
        // Optimistically update local array and cache
        expenses.remove(atOffsets: offsets)
        saveExpenses()
        
        Task {
            // Pull latest expenses from server
            await fetchExpenses()
            
            // Remove matching IDs
            expenses.removeAll(where: { idsToDelete.contains($0.id) })
            saveExpenses()
            
            _ = await uploadExpenses()
        }
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
