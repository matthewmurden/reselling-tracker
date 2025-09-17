import SwiftUI
import CoreData
import PhotosUI

private let currencyFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.currencyCode = "GBP"
    return f
}()

struct ItemDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var item: Item

    @State private var name = ""
    @State private var brand = ""
    @State private var category = ""
    @State private var purchasePriceText = ""
    @State private var salePriceText = ""
    @State private var marketplace = ""

    // Dates (local state; saved on Save)
    @State private var addedAt: Date = Date()          // NEW
    @State private var soldAt: Date? = nil             // NEW

    // Local “sold” switch so nothing is persisted until Save
    @State private var soldSwitch = false

    // Receipts (local state; saved on Save)
    @State private var purchaseReceiptData: Data?
    @State private var saleReceiptData: Data?

    // Pickers
    @State private var showPurchaseReceiptPicker = false
    @State private var purchaseReceiptSelection: PhotosPickerItem?

    @State private var showSaleReceiptPicker = false
    @State private var saleReceiptSelection: PhotosPickerItem?

    // Binding to edit optional soldAt in a DatePicker
    private var soldDateBinding: Binding<Date> {        // NEW
        Binding(
            get: { soldAt ?? Date() },
            set: { soldAt = $0 }
        )
    }

    var body: some View {
        Form {
            Section(header: Text("Photo")) {
                // Placeholder until a product photo picker is added
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.secondary.opacity(0.12))
                    .frame(height: 72)
                    .overlay(
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                            Text("Photo picker coming next…")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    )
            }

            Section(header: Text("Basics")) {
                TextField("Name", text: $name)
                TextField("Brand", text: $brand)
                TextField("Category", text: $category)
            }

            // NEW: Dates section with editable Date Added
            Section(header: Text("Dates")) {             // NEW
                DatePicker("Date Added", selection: $addedAt, displayedComponents: [.date])
            }

            Section(header: Text("Purchase")) {
                TextField("Purchase Price (£)", text: $purchasePriceText)
                    .keyboardType(.decimalPad)

                // Purchase receipt UI
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "doc.text.viewfinder")
                        Text("Purchase Receipt")
                            .fontWeight(.semibold)
                    }

                    if let data = purchaseReceiptData, let ui = UIImage(data: data) {
                        HStack(spacing: 12) {
                            Image(uiImage: ui)
                                .resizable().scaledToFill()
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))

                            Button("Replace") { showPurchaseReceiptPicker = true }
                            Button("Remove")  { purchaseReceiptData = nil }
                                .foregroundStyle(.red)

                            Spacer()
                        }
                    } else {
                        Button {
                            showPurchaseReceiptPicker = true
                        } label: {
                            Label("Attach purchase receipt", systemImage: "paperclip")
                        }
                    }
                }
                .padding(.top, 4)
            }

            Section(header: Text("Sell")) {
                Toggle("Marked as Sold", isOn: $soldSwitch)

                TextField("Sale Price (£)", text: $salePriceText)
                    .keyboardType(.decimalPad)
                    .disabled(!soldSwitch)

                TextField("Marketplace (eBay, StockX…)", text: $marketplace)
                    .disabled(!soldSwitch)

                // NEW: Show a Date Sold picker only when sold is ON
                if soldSwitch {                            // NEW
                    DatePicker("Date Sold", selection: soldDateBinding, displayedComponents: [.date])
                }

                // Sale receipt UI (only when sold is ON)
                if soldSwitch {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checklist.checked")
                            Text("Sale Receipt")
                                .fontWeight(.semibold)
                        }

                        if let data = saleReceiptData, let ui = UIImage(data: data) {
                            HStack(spacing: 12) {
                                Image(uiImage: ui)
                                    .resizable().scaledToFill()
                                    .frame(width: 56, height: 56)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))

                                Button("Replace") { showSaleReceiptPicker = true }
                                Button("Remove")  { saleReceiptData = nil }
                                    .foregroundStyle(.red)

                                Spacer()
                            }
                        } else {
                            Button {
                                showSaleReceiptPicker = true
                            } label: {
                                Label("Attach sale receipt", systemImage: "paperclip")
                            }
                        }
                    }
                    .padding(.top, 4)
                }

                // Live profit preview from local edits
                if let val = Double(salePriceText), val > 0, soldSwitch {
                    let buy = Double(purchasePriceText) ?? item.purchasePrice
                    let p = val - buy
                    HStack {
                        Text("Profit")
                        Spacer()
                        Text(currencyFormatter.string(from: p as NSNumber) ?? "£0")
                            .fontWeight(.semibold)
                            .foregroundStyle(p >= 0 ? .green : .red)
                    }
                }
            }
        }
        .navigationTitle(item.name ?? "Item")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
            }
        }
        .onAppear(perform: loadState)
        // Clear local sale fields & sale receipt immediately if unselling (persist on Save)
        .onChange(of: soldSwitch) { isOn in
            if !isOn {
                salePriceText   = ""
                marketplace     = ""
                saleReceiptData = nil
                soldAt          = nil            // NEW: clear sold date when unselling
            } else if soldAt == nil {
                soldAt = Date()                  // NEW: default sold date to today when toggled on
            }
        }
        // Pickers as modifiers (keeps the type-checker happy)
        .photosPicker(isPresented: $showPurchaseReceiptPicker,
                      selection: $purchaseReceiptSelection,
                      matching: .images)
        .onChange(of: purchaseReceiptSelection) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    purchaseReceiptData = data
                }
            }
        }
        .photosPicker(isPresented: $showSaleReceiptPicker,
                      selection: $saleReceiptSelection,
                      matching: .images)
        .onChange(of: saleReceiptSelection) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    saleReceiptData = data
                }
            }
        }
    }

    // MARK: - State & Save

    private func loadState() {
        name = item.name ?? ""
        brand = item.brand ?? ""
        category = item.category ?? ""
        purchasePriceText = item.purchasePrice == 0 ? "" : String(format: "%.2f", item.purchasePrice)

        soldSwitch    = item.isSold || item.salePrice > 0
        salePriceText = item.salePrice == 0 ? "" : String(format: "%.2f", item.salePrice)
        marketplace   = item.marketplace ?? ""

        // ✅ Safe KVC reads
        if item.entity.attributesByName["purchaseReceipt"] != nil {
            purchaseReceiptData = item.value(forKey: "purchaseReceipt") as? Data
        } else {
            purchaseReceiptData = nil
        }
        if item.entity.attributesByName["saleReceipt"] != nil {
            saleReceiptData = item.value(forKey: "saleReceipt") as? Data
        } else {
            saleReceiptData = nil
        }

        // ✅ NEW: Dates (safe if attributes don’t exist yet)
        if item.entity.attributesByName["addedAt"] != nil,
           let d = item.value(forKey: "addedAt") as? Date {
            addedAt = d
        } else {
            addedAt = Date()
        }

        if item.entity.attributesByName["soldAt"] != nil {
            soldAt = item.value(forKey: "soldAt") as? Date
        } else {
            soldAt = nil
        }

        // Keep toggle in sync with presence of soldAt, if available
        if item.entity.attributesByName["soldAt"] != nil {
            soldSwitch = (soldAt != nil)
        }
    }

    private func save() {
        // Basics
        item.name = name.isEmpty ? nil : name
        item.brand = brand.isEmpty ? nil : brand
        item.category = category.isEmpty ? nil : category

        // Purchase
        if let buy = Double(purchasePriceText) { item.purchasePrice = buy }
        // ✅ Safe KVC write
        if item.entity.attributesByName["purchaseReceipt"] != nil {
            item.setValue(purchaseReceiptData, forKey: "purchaseReceipt")
        }

        // Dates
        if item.entity.attributesByName["addedAt"] != nil {           // NEW
            item.setValue(addedAt, forKey: "addedAt")
        }

        // Sell (respect the switch)
        if soldSwitch {
            let sale = Double(salePriceText) ?? 0
            item.salePrice   = max(0, sale)
            item.marketplace = marketplace.isEmpty ? nil : marketplace
            // ✅ Safe KVC write
            if item.entity.attributesByName["saleReceipt"] != nil {
                item.setValue(saleReceiptData, forKey: "saleReceipt")
            }
            if item.entity.attributesByName["soldAt"] != nil {        // NEW
                item.setValue(soldAt ?? Date(), forKey: "soldAt")
            }
            item.isSold      = true                                   // NEW: mirror toggle
        } else {
            item.salePrice   = 0
            item.marketplace = nil
            if item.entity.attributesByName["saleReceipt"] != nil {
                item.setValue(nil, forKey: "saleReceipt")
            }
            if item.entity.attributesByName["soldAt"] != nil {        // NEW
                item.setValue(nil, forKey: "soldAt")
            }
            item.isSold      = false
        }

        try? viewContext.save()

        // Nudge the list to refresh when you navigate back
        item.objectWillChange.send()
        viewContext.refresh(item, mergeChanges: true)
    }
}
