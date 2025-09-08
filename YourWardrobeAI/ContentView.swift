import SwiftUI
import CoreData

private let currencyFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.currencyCode = "GBP"
    return f
}()

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: false)],
        animation: .default
    )
    private var items: FetchedResults<Item>

    @State private var showingAdd = false
    @State private var query = ""
    @State private var showSoldOnly = false   // OFF = unsold only, ON = sold only

    // Filter using robust "sold" condition (isSold or salePrice > 0)
    var filtered: [Item] {
        items.filter { it in
            let matchesQuery =
                query.isEmpty ||
                (it.name ?? "").localizedCaseInsensitiveContains(query) ||
                (it.brand ?? "").localizedCaseInsensitiveContains(query) ||
                (it.category ?? "").localizedCaseInsensitiveContains(query)

            let sold = it.isSold || it.salePrice > 0
            // OFF -> unsold only; ON -> sold only
            let passesSoldFilter = showSoldOnly ? sold : !sold

            return matchesQuery && passesSoldFilter
        }
    }

    // Totals for the dashboard summary (all items; not tied to filter)
    var totals: (spent: Double, sales: Double, profit: Double) {
        var spent = 0.0, sales = 0.0
        for it in items {
            spent += it.purchasePrice
            if it.salePrice > 0 { sales += it.salePrice }
        }
        return (spent, sales, sales - spent)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 8) {
                // Summary bar
                HStack {
                    VStack(alignment: .leading) {
                        Text("Spent")
                        Text(currencyFormatter.string(from: totals.spent as NSNumber) ?? "£0")
                            .fontWeight(.semibold)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Sales")
                        Text(currencyFormatter.string(from: totals.sales as NSNumber) ?? "£0")
                            .fontWeight(.semibold)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Profit")
                        Text(currencyFormatter.string(from: totals.profit as NSNumber) ?? "£0")
                            .fontWeight(.bold)
                            .foregroundStyle(totals.profit >= 0 ? .green : .red)
                    }
                }
                .font(.subheadline)
                .padding(.horizontal)

                List {
                    ForEach(filtered) { item in
                        NavigationLink {
                            ItemDetailView(item: item)
                        } label: {
                            ItemRow(item: item) // ObservedObject row for immediate refresh
                        }
                    }
                    .onDelete(perform: deleteItems)
                }
                .listStyle(.plain)
            }
            .navigationTitle("Resell Profit")
            .searchable(text: $query, prompt: "Search name, brand, category")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Toggle(isOn: $showSoldOnly) {
                        Text("Sold") // OFF: Unsold only, ON: Sold only
                    }
                    .toggleStyle(.switch)
                }
                ToolbarItem(placement: .navigationBarTrailing) { EditButton() }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingAdd = true } label: {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddItemView()
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { filtered[$0] }.forEach(viewContext.delete)
            try? viewContext.save()
        }
    }
}
