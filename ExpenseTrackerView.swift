import SwiftUI
import MapKit

public struct ExpenseTrackerView: View {
    @ObservedObject var store: TripStore
    
    @State private var showingAddExpense = false
    @State private var expenseTitle = ""
    @State private var expenseAmount = ""
    @State private var paidBy = ""
    @State private var splitAmong = Set<String>()
    
    @State private var activeTab = 0 // 0: Expenses, 1: Balances & Settlements, 2: Map
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var expenseMapPosition: MapCameraPosition = .automatic
    
    // For Location Manager
    @StateObject private var locationManager = LocationManager()
    
    // For Location Picker inside Add Expense
    @State private var selectedLocation: LocationInfo? = nil
    @State private var locationSearchQuery = ""
    @State private var locationSearchResults = [LocationInfo]()
    @State private var isSearchingLocation = false
    
    public init(store: TripStore) {
        self.store = store
    }
    
    public var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // 1. Map Background (shows overview of the trip region) - only for lists, not active map
                if activeTab != 2 {
                    Map(position: $mapPosition)
                        .disabled(true)
                        .ignoresSafeArea()
                        .opacity(0.4)
                        .blur(radius: 0.8)
                    
                    Color(.systemBackground)
                        .opacity(0.15)
                        .ignoresSafeArea()
                }
                
                // 2. Main Content
                VStack(spacing: 0) {
                    Picker("Tab", selection: $activeTab) {
                        Text("Expenses").tag(0)
                        Text("Balances").tag(1)
                        Text("Map").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    
                    if activeTab == 0 {
                        expensesListTab
                    } else if activeTab == 1 {
                        balancesTab
                    } else {
                        expenseMapTab
                    }
                }
                
                // 3. Top Gradient Blur Overlay (smoothly fades content as it scrolls up)
                if activeTab != 2 {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .mask(
                            LinearGradient(
                                colors: [.black, .black.opacity(0.85), .black.opacity(0.5), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 110)
                        .ignoresSafeArea(edges: .top)
                        .allowsHitTesting(false)
                }
            }
            .navigationTitle("Expenses 💸")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingAddExpense) {
                addExpenseSheet
            }
            .onAppear {
                setInitialMapPosition()
                Task {
                    await store.fetchExpenses()
                }
            }
        }
    }
    
    private func setInitialMapPosition() {
        if let firstStep = store.trip?.steps.first {
            let region = MKCoordinateRegion(
                center: firstStep.location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 12, longitudeDelta: 12)
            )
            mapPosition = .region(region)
        }
    }
    
    private func setExpenseMapPosition() {
        let localized = store.expenses.compactMap { $0.location }
        if !localized.isEmpty {
            let avgLat = localized.map { $0.latitude }.reduce(0, +) / Double(localized.count)
            let avgLng = localized.map { $0.longitude }.reduce(0, +) / Double(localized.count)
            let region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: avgLat, longitude: avgLng),
                span: MKCoordinateSpan(latitudeDelta: 4, longitudeDelta: 4)
            )
            expenseMapPosition = .region(region)
        } else if let firstStep = store.trip?.steps.first {
            let region = MKCoordinateRegion(
                center: firstStep.location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 12, longitudeDelta: 12)
            )
            expenseMapPosition = .region(region)
        }
    }
    
    // MARK: - Expenses List Tab
    
    private var expensesListTab: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                if store.expenses.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "creditcard.and.123")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                            .padding(.top, 80)
                        Text("No Expenses Yet")
                            .font(.headline)
                        Text("Keep track of who paid for what during the trip. Tap the button below to add an expense.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    LazyVStack(spacing: 12) {
                        Spacer()
                            .frame(height: 12)
                        
                        ForEach(store.expenses) { expense in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(expense.title)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    HStack(spacing: 6) {
                                        Text("Paid by \(expense.paidBy)")
                                        if let loc = expense.location {
                                            Text("•")
                                            Image(systemName: "mappin.and.ellipse")
                                                .font(.caption)
                                            Text(loc.name)
                                                .font(.caption)
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                HStack(spacing: 12) {
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text(String(format: "$%.2f", expense.amount))
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text("\(expense.splitAmong.count) split")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Button {
                                        if let idx = store.expenses.firstIndex(where: { $0.id == expense.id }) {
                                            store.deleteExpense(at: IndexSet(integer: idx))
                                        }
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red.opacity(0.8))
                                            .font(.system(size: 14))
                                            .padding(8)
                                            .background(Color.red.opacity(0.1))
                                            .clipShape(Circle())
                                    }
                                }
                            }
                            .padding()
                            .liquidGlassStyle(cornerRadius: 14, fillOpacity: 0.03, borderOpacity: 0.45)
                            .padding(.horizontal)
                        }
                        
                        Spacer()
                            .frame(height: 20)
                    }
                }
            }
            .refreshable {
                await store.fetchExpenses()
            }
            
            Button {
                if let users = store.trip?.users {
                    paidBy = store.selectedUser ?? users.first ?? ""
                    splitAmong = Set(users)
                }
                expenseTitle = ""
                expenseAmount = ""
                selectedLocation = nil
                locationSearchQuery = ""
                locationSearchResults.removeAll()
                showingAddExpense = true
            } label: {
                Label("Add Expense", systemImage: "plus")
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentColor)
            .padding()
        }
    }
    
    // MARK: - Balances & Settlements Tab
    
    private var balancesTab: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                Spacer()
                    .frame(height: 12)
                
                // 1. Group Balances
                VStack(alignment: .leading, spacing: 12) {
                    Text("Group Balances")
                        .font(.title3)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    let balances = store.calculateBalances()
                    ForEach(balances.sorted(by: { $0.key < $1.key }), id: \.key) { name, balance in
                        HStack {
                            Text(name)
                                .font(.body)
                                .fontWeight(.semibold)
                            Spacer()
                            Text(String(format: balance >= 0 ? "+$%.2f" : "-$%.2f", abs(balance)))
                                .font(.body)
                                .fontWeight(.bold)
                                .foregroundColor(balance >= 0 ? .green : .red)
                        }
                        .padding()
                        .liquidGlassStyle(cornerRadius: 12, fillOpacity: 0.03, borderOpacity: 0.45)
                        .padding(.horizontal)
                    }
                }
                
                // 2. Settlements Plan
                VStack(alignment: .leading, spacing: 12) {
                    Text("Suggested Settlement Plan")
                        .font(.title3)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    let settlements = store.calculateSettlements()
                    if settlements.isEmpty {
                        Text("Everyone is even! No settlements needed.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .liquidGlassStyle(cornerRadius: 12, fillOpacity: 0.03, borderOpacity: 0.45)
                            .padding(.horizontal)
                    } else {
                        ForEach(settlements) { settlement in
                            HStack {
                                Image(systemName: "arrow.right.circle.fill")
                                    .foregroundColor(Color.accentColor)
                                    .font(.title2)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(settlement.from) owes \(settlement.to)")
                                        .font(.body)
                                        .fontWeight(.medium)
                                }
                                
                                Spacer()
                                
                                Text(String(format: "$%.2f", settlement.amount))
                                    .font(.body)
                                    .fontWeight(.bold)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 12)
                                    .background(Color.accentColor.opacity(0.15))
                                    .foregroundColor(Color.accentColor)
                                    .cornerRadius(8)
                            }
                            .padding()
                            .liquidGlassStyle(cornerRadius: 12, fillOpacity: 0.03, borderOpacity: 0.45)
                            .padding(.horizontal)
                        }
                    }
                }
                
                Spacer()
                    .frame(height: 20)
            }
        }
        .refreshable {
            await store.fetchExpenses()
        }
    }
    
    // MARK: - Expense Map Tab
    
    private var expenseMapTab: some View {
        ZStack(alignment: .bottom) {
            Map(position: $expenseMapPosition) {
                ForEach(store.expenses.filter { $0.location != nil }) { expense in
                    if let loc = expense.location {
                        Annotation(expense.title, coordinate: loc.coordinate) {
                            VStack(spacing: 4) {
                                Text(String(format: "$%.2f", expense.amount))
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(Color.accentColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                                    .shadow(radius: 2)
                                
                                Text(expense.title)
                                    .font(.system(size: 9))
                                    .padding(.vertical, 2)
                                    .padding(.horizontal, 4)
                                    .background(Color(.systemBackground).opacity(0.85))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .onAppear {
            setExpenseMapPosition()
        }
    }
    
    // MARK: - Add Expense Sheet
    
    private var addExpenseSheet: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("What did you pay for?", text: $expenseTitle)
                    TextField("Amount ($)", text: $expenseAmount)
                        .keyboardType(.decimalPad)
                }
                
                Section("Location") {
                    if let location = selectedLocation {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(location.name)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text(String(format: "Lat: %.4f, Lng: %.4f", location.latitude, location.longitude))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("Remove") {
                                selectedLocation = nil
                            }
                            .foregroundColor(.red)
                            .buttonStyle(.borderless)
                        }
                    } else {
                        Text("No location selected")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Button {
                        locationManager.requestLocation()
                        if let loc = locationManager.location {
                            selectedLocation = LocationInfo(
                                name: "Current Location",
                                latitude: loc.coordinate.latitude,
                                longitude: loc.coordinate.longitude
                            )
                        } else {
                            // Temporary fallback during permission check
                            selectedLocation = LocationInfo(
                                name: "Current Location",
                                latitude: 37.0902,
                                longitude: -95.7129
                            )
                            // Async check again in 1s
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                if let loc = locationManager.location {
                                    selectedLocation = LocationInfo(
                                        name: "Current Location",
                                        latitude: loc.coordinate.latitude,
                                        longitude: loc.coordinate.longitude
                                    )
                                }
                            }
                        }
                    } label: {
                        Label("Use Current Location (Here)", systemImage: "location.fill")
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField("Search Map...", text: $locationSearchQuery)
                                .textFieldStyle(.roundedBorder)
                                .disableAutocorrection(true)
                                .autocapitalization(.none)
                            
                            Button("Search") {
                                performLocationSearch()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        
                        if isSearchingLocation {
                            ProgressView()
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 4)
                        } else if !locationSearchResults.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(locationSearchResults, id: \.self) { result in
                                        Button {
                                            selectedLocation = result
                                            locationSearchResults.removeAll()
                                            locationSearchQuery = ""
                                        } label: {
                                            Text(result.name)
                                                .font(.caption)
                                                .padding(.vertical, 6)
                                                .padding(.horizontal, 12)
                                                .background(Color.accentColor.opacity(0.15))
                                                .cornerRadius(8)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                
                if let users = store.trip?.users {
                    Section("Paid By") {
                        Picker("Payer", selection: $paidBy) {
                            ForEach(users, id: \.self) { user in
                                Text(user).tag(user)
                            }
                        }
                    }
                    
                    Section("Split Among") {
                        ForEach(users, id: \.self) { user in
                            Toggle(user, isOn: Binding(
                                get: { splitAmong.contains(user) },
                                set: { selected in
                                    if selected {
                                        splitAmong.insert(user)
                                    } else {
                                        splitAmong.remove(user)
                                    }
                                }
                            ))
                        }
                    }
                }
            }
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingAddExpense = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let amount = Double(expenseAmount), !expenseTitle.isEmpty {
                            store.addExpense(
                                title: expenseTitle,
                                amount: amount,
                                paidBy: paidBy,
                                splitAmong: Array(splitAmong),
                                location: selectedLocation
                            )
                            showingAddExpense = false
                        }
                    }
                    .disabled(expenseTitle.isEmpty || Double(expenseAmount) == nil || splitAmong.isEmpty)
                }
            }
            .onChange(of: locationManager.location) { oldVal, newVal in
                if let loc = newVal, selectedLocation?.name == "Current Location" {
                    selectedLocation = LocationInfo(
                        name: "Current Location",
                        latitude: loc.coordinate.latitude,
                        longitude: loc.coordinate.longitude
                    )
                }
            }
        }
    }
    
    private func performLocationSearch() {
        guard !locationSearchQuery.isEmpty else { return }
        isSearchingLocation = true
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = locationSearchQuery
        
        if let firstStep = store.trip?.steps.first {
            request.region = MKCoordinateRegion(
                center: firstStep.location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 2.0, longitudeDelta: 2.0)
            )
        }
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            isSearchingLocation = false
            guard let response = response else { return }
            locationSearchResults = response.mapItems.map { item in
                LocationInfo(
                    name: item.name ?? "Unknown Location",
                    latitude: item.placemark.coordinate.latitude,
                    longitude: item.placemark.coordinate.longitude
                )
            }
        }
    }
}
