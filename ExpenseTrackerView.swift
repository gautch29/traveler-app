import SwiftUI
import MapKit

public struct ExpenseTrackerView: View {
    @ObservedObject var store: TripStore
    
    @State private var showingAddExpense = false
    @State private var expenseTitle = ""
    @State private var expenseAmount = ""
    @State private var paidBy = ""
    @State private var splitAmong = Set<String>()
    
    @State private var activeTab = 0 // 0: Expenses, 1: Balances & Settlements
    @State private var mapPosition: MapCameraPosition = .automatic
    
    public init(store: TripStore) {
        self.store = store
    }
    
    public var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // 1. Map Background (shows overview of the trip region)
                Map(position: $mapPosition)
                    .disabled(true)
                    .ignoresSafeArea()
                    .opacity(0.4)
                    .blur(radius: 0.8)
                
                Color(.systemBackground)
                    .opacity(0.15)
                    .ignoresSafeArea()
                
                // 2. Main Content
                VStack(spacing: 0) {
                    Picker("Tab", selection: $activeTab) {
                        Text("Expenses").tag(0)
                        Text("Balances & Settlements").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    
                    if activeTab == 0 {
                        expensesListTab
                    } else {
                        balancesTab
                    }
                }
                
                // 3. Top Gradient Blur Overlay (smoothly fades content as it scrolls up)
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
                                    Text("Paid by \(expense.paidBy)")
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
    
    // MARK: - Add Expense Sheet
    
    private var addExpenseSheet: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("What did you pay for?", text: $expenseTitle)
                    TextField("Amount ($)", text: $expenseAmount)
                        .keyboardType(.decimalPad)
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
                            store.addExpense(title: expenseTitle, amount: amount, paidBy: paidBy, splitAmong: Array(splitAmong))
                            showingAddExpense = false
                        }
                    }
                    .disabled(expenseTitle.isEmpty || Double(expenseAmount) == nil || splitAmong.isEmpty)
                }
            }
        }
    }
}
