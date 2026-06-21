import SwiftUI

public struct ExpenseTrackerView: View {
    @ObservedObject var store: TripStore
    
    @State private var showingAddExpense = false
    @State private var expenseTitle = ""
    @State private var expenseAmount = ""
    @State private var paidBy = ""
    @State private var splitAmong = Set<String>()
    
    @State private var activeTab = 0 // 0: Expenses, 1: Balances & Settlements
    
    public init(store: TripStore) {
        self.store = store
    }
    
    public var body: some View {
        NavigationStack {
            VStack {
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
            .navigationTitle("Expenses 💸")
            .sheet(isPresented: $showingAddExpense) {
                addExpenseSheet
            }
        }
    }
    
    // MARK: - Expenses List Tab
    
    private var expensesListTab: some View {
        VStack {
            if store.expenses.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "creditcard.and.123")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                        .padding(.top, 40)
                    Text("No Expenses Yet")
                        .font(.headline)
                    Text("Keep track of who paid for what during the trip. Tap the button below to add an expense.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Spacer()
                }
            } else {
                List {
                    ForEach(store.expenses) { expense in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(expense.title)
                                    .font(.headline)
                                Text("Paid by \(expense.paidBy)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(String(format: "$%.2f", expense.amount))
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("\(expense.splitAmong.count) split")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: store.deleteExpense)
                }
            }
            
            Button {
                // Initialize default values for the sheet
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
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
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
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
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
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(12)
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
                                    .background(Color.accentColor.opacity(0.1))
                                    .foregroundColor(Color.accentColor)
                                    .cornerRadius(8)
                            }
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
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
