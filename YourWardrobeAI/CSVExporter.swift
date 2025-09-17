import Foundation
import CoreData

struct CSVExporter {
    // MARK: - Public API

    /// Fetches all Item rows and writes a CSV in /tmp, returning the file URL.
    static func exportAllItemsURL(using context: NSManagedObjectContext,
                                  filenamePrefix: String = "YourWardrobeAI-Items") -> URL? {
        let request = NSFetchRequest<Item>(entityName: "Item")
        request.sortDescriptors = [
            NSSortDescriptor(key: "addedAt", ascending: true),
            NSSortDescriptor(key: "timestamp", ascending: true)
        ]

        do {
            let items = try context.fetch(request)
            return exportAllItemsURL(from: items, filenamePrefix: filenamePrefix)
        } catch {
            print("CSV export fetch failed: \(error)")
            return nil
        }
    }

    /// Writes a CSV for the provided items to /tmp and returns the file URL.
    static func exportAllItemsURL(from items: [Item],
                                  filenamePrefix: String = "YourWardrobeAI-Items") -> URL? {
        let csv = makeCSV(from: items)
        return writeCSV(csv, filenamePrefix: filenamePrefix)
    }

    // MARK: - Implementation

    private static func makeCSV(from items: [Item]) -> String {
        var rows: [String] = []

        // Header – add/remove columns here as needed
        rows.append([
            "id",
            "name",
            "brand",
            "category",
            "purchasePrice",
            "salePrice",
            "addedAt",
            "soldAt",
            "marketplace",
            "isSold",
            "hasPurchaseReceipt",
            "hasSaleReceipt"
        ].joined(separator: ","))

        for item in items {
            // Prefer generated accessors if you have them; keep KVC fallbacks for safety.
            let id           = item.value(forKey: "id") as? String
            let name         = item.name
            let brand        = item.brand
            let category     = item.category
            let purchase     = item.purchasePrice                 // Double
            let sale         = item.salePrice                     // Double
            let added        = (item.value(forKey: "addedAt") as? Date) ?? item.timestamp
            let sold         = item.value(forKey: "soldAt") as? Date
            let marketplace  = item.marketplace
            let isSold       = (item.value(forKey: "soldAt") as? Date) != nil || item.isSold

            // Receipts (don’t export images, just flags)
            let hasPurchaseReceipt = (item.entity.attributesByName["purchaseReceipt"] != nil) &&
                                     ((item.value(forKey: "purchaseReceipt") as? Data) != nil)
            let hasSaleReceipt     = (item.entity.attributesByName["saleReceipt"] != nil) &&
                                     ((item.value(forKey: "saleReceipt") as? Data) != nil)

            let row = [
                csvField(id),
                csvField(name),
                csvField(brand),
                csvField(category),
                csvNumber(purchase),
                csvNumber(sale),
                csvField(isoDate(added)),
                csvField(isoDate(sold)),
                csvField(marketplace),
                csvField(isSold ? "true" : "false"),
                csvField(hasPurchaseReceipt ? "true" : "false"),
                csvField(hasSaleReceipt ? "true" : "false")
            ].joined(separator: ",")

            rows.append(row)
        }

        return rows.joined(separator: "\n")
    }

    private static func writeCSV(_ csv: String, filenamePrefix: String) -> URL? {
        let stamp = fileDateStamp(Date())
        let filename = "\(filenamePrefix)-\(stamp).csv"

        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let url = tempDir.appendingPathComponent(filename, conformingTo: .commaSeparatedText)

        do {
            try csv.data(using: .utf8)?.write(to: url, options: .atomic)
            return url
        } catch {
            print("CSV write failed: \(error)")
            return nil
        }
    }

    // MARK: - Helpers

    /// Properly quote CSV field. Doubles embedded quotes and wraps in quotes if needed.
    private static func csvField(_ value: String?) -> String {
        let s = value ?? ""
        let needsQuoting = s.contains(",") || s.contains("\"") || s.contains("\n") || s.contains("\r")
        if needsQuoting {
            let doubled = s.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(doubled)\""
        } else {
            return s
        }
    }

    /// Format number with period decimal separator for spreadsheet friendliness.
    private static func csvNumber(_ value: Double) -> String {
        // Avoid locale commas; ensure consistent '.' decimal
        if value == 0 { return "0" }
        return String(format: "%.2f", value)
    }

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static func isoDate(_ date: Date?) -> String {
        guard let date else { return "" }
        return iso.string(from: date)
    }

    private static func fileDateStamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f.string(from: date)
    }
}
