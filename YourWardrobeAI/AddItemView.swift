import SwiftUI
import CoreData
import PhotosUI

struct AddItemView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var brand = ""
    @State private var category = ""
    @State private var priceText = ""

    // Receipt picker
    @State private var showReceiptPicker = false
    @State private var receiptSelection: PhotosPickerItem?
    @State private var receiptData: Data?

    var body: some View {
        NavigationView {
            Form {
                Section("Basics") {
                    TextField("Name (e.g. Nike Dunks)", text: $name)
                    TextField("Brand (e.g. Nike)", text: $brand)
                    TextField("Category (e.g. Sneakers)", text: $category)
                }

                Section("Purchase") {
                    TextField("Purchase Price (£)", text: $priceText)
                        .keyboardType(.decimalPad)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "doc.text.viewfinder")
                            Text("Purchase Receipt")
                                .fontWeight(.semibold)
                        }

                        if let data = receiptData,
                           let uiImg = UIImage(data: data) {
                            // Small preview with remove button
                            HStack(spacing: 12) {
                                Image(uiImage: uiImg)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 56, height: 56)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))

                                Button("Remove") { receiptData = nil }
                                    .foregroundStyle(.red)

                                Spacer()
                            }
                        } else {
                            Button {
                                showReceiptPicker = true
                            } label: {
                                Label("Attach purchase receipt", systemImage: "paperclip")
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .navigationTitle("Add Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            // Photos picker modifier
            .photosPicker(isPresented: $showReceiptPicker,
                          selection: $receiptSelection,
                          matching: .images)
            .onChange(of: receiptSelection) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        receiptData = data
                    }
                }
            }
        }
    }

    private func save() {
        let item = Item(context: viewContext)
        item.name = name
        item.brand = brand.isEmpty ? nil : brand
        item.category = category.isEmpty ? nil : category
        item.purchasePrice = Double(priceText) ?? 0
        item.timestamp = Date()
        item.purchaseReceipt = receiptData   // <-- store receipt image

        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Save failed: \(error)")
        }
    }
}
