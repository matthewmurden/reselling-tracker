import SwiftUI
import CoreData

private let currencyFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.currencyCode = "GBP"
    return f
}()

struct ItemRow: View {
    @ObservedObject var item: Item

    var body: some View {
        HStack(spacing: 12) {
            Thumbnail(data: item.image)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name ?? "Unnamed")
                    .font(.headline)
                HStack(spacing: 6) {
                    Text(item.brand ?? "—")
                    Text("•")
                    Text(item.category ?? "—")
                }
                .foregroundStyle(.secondary)
                .font(.subheadline)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                // purchase price
                Text(currencyFormatter.string(from: item.purchasePrice as NSNumber) ?? "£0")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // profit if sale price exists
                if item.salePrice > 0 {
                    let profit = item.salePrice - item.purchasePrice
                    Text(currencyFormatter.string(from: profit as NSNumber) ?? "£0")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(profit >= 0 ? .green : .red)
                }

                // status chip (robust)
                let sold = item.isSold || item.salePrice > 0
                Text(sold ? "Sold" : "Unsold")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background((sold ? Color.green.opacity(0.15) : Color.yellow.opacity(0.15)))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
        // helps SwiftUI invalidate the row when Core Data object changes
        .id(item.objectID)
    }
}
