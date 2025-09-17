import SwiftUI
import CoreData
import Charts

struct DashboardView: View {
    @Environment(\.managedObjectContext) private var ctx

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Item.addedAt, ascending: true),
            NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)
        ]
    )
    private var items: FetchedResults<Item>

    @State private var showTimeToSell = false
    @State private var monthCount = 12

    // 👇 NEW: force redraw token
    @State private var reloadID = UUID()

    var body: some View {
        NavigationView {
            List {
                Section {
                    MonthlySRPChart(stats: monthlyStats(limitToLast: monthCount))
                        .frame(height: 300)
                        .id(reloadID) // 👈 force chart to rebuild when ID changes

                    SRPSummaryRow(stats: monthlyStats(limitToLast: monthCount))
                        .id(reloadID) // 👈 summary too
                } header: {
                    Text("Spend, Revenue & Profit")
                } footer: {
                    HStack {
                        Stepper("Show \(monthCount) months", value: $monthCount, in: 3...36)
                        Spacer()
                        Toggle("Time-to-Sell", isOn: $showTimeToSell)
                    }
                }

                if showTimeToSell {
                    Section("Time-to-Sell (days)") {
                        TimeToSellChart(points: timeToSellPoints())
                            .frame(height: 240)
                            .id(reloadID)
                        let tts = timeToSellPoints()
                        if !tts.isEmpty {
                            let avg = tts.map(\.days).reduce(0, +) / Double(tts.count)
                            Label("Average: \(Int(avg.rounded())) days", systemImage: "clock")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("No sold items yet.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        exportAllItems()
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                }
            }
            // 👇 Recompute/redraw when the fetch results change count
            .animation(.default, value: items.count)

            // 👇 Listen to Core Data changes on this context
            .onReceive(NotificationCenter.default.publisher(
                for: .NSManagedObjectContextObjectsDidChange,
                object: ctx
            )) { _ in
                reloadID = UUID()
            }

            
        }
    }
}

// MARK: - Data shaping

private struct MonthlyStats: Identifiable {
    var id: Date { monthStart }
    let monthStart: Date  // first day of month at 00:00
    let spend: Double     // sum of purchasePrice for items with addedAt in this month
    let revenue: Double   // sum of salePrice for items with soldAt in this month
    var profit: Double { revenue - spend }
}

private extension DashboardView {

    func monthlyStats(limitToLast n: Int) -> [MonthlyStats] {
        // Guard: no items -> empty
        if items.isEmpty { return [] }

        let cal = Calendar.current

        // Build a dict keyed by month start date
        var buckets: [Date: (spend: Double, revenue: Double)] = [:]

        for item in items {
            // Spend by addedAt
            if let added = (item.value(forKey: "addedAt") as? Date) ?? item.timestamp {
                let m = cal.date(from: cal.dateComponents([.year, .month], from: added)) ?? added
                buckets[m, default: (0, 0)].spend += item.purchasePrice
            }

            // Revenue by soldAt
            if let sold = item.value(forKey: "soldAt") as? Date {
                let m = cal.date(from: cal.dateComponents([.year, .month], from: sold)) ?? sold
                buckets[m, default: (0, 0)].revenue += item.salePrice
            }
        }

        // Turn into array, sort by month, and optionally limit to last n months
        var stats = buckets
            .map { MonthlyStats(monthStart: $0.key, spend: $0.value.spend, revenue: $0.value.revenue) }
            .sorted { $0.monthStart < $1.monthStart }

        if n > 0, stats.count > n {
            stats = Array(stats.suffix(n))
        }
        return stats
    }

    struct TTSEntry: Identifiable {
        let id = UUID()
        let soldDate: Date
        let days: Double
    }

    func timeToSellPoints() -> [TTSEntry] {
        items.compactMap { item in
            guard
                let added = (item.value(forKey: "addedAt") as? Date) ?? item.timestamp,
                let sold  = item.value(forKey: "soldAt") as? Date
            else { return nil }
            let days = sold.timeIntervalSince(added) / 86_400
            return TTSEntry(soldDate: sold, days: max(0, days))
        }
        .sorted { $0.soldDate < $1.soldDate }
    }

    // MARK: Export using your CSVExporter
    func exportAllItems() {
        if let url = CSVExporter.exportAllItemsURL(from: Array(items)) {
            let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            UIApplication.shared.topMostViewController()?.present(av, animated: true)
        }
    }
}

// Helper to find top VC for share sheet (simple approach)
#if canImport(UIKit)
private extension UIApplication {
    func topMostViewController(base: UIViewController? = UIApplication.shared.connectedScenes
        .compactMap { ($0 as? UIWindowScene)?.keyWindow }
        .first?.rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topMostViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            return topMostViewController(base: tab.selectedViewController)
        }
        if let presented = base?.presentedViewController {
            return topMostViewController(base: presented)
        }
        return base
    }
}
#endif

// MARK: - Charts

private struct MonthlySRPChart: View {
    let stats: [MonthlyStats]

    private var monthFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f
    }

    var body: some View {
        Chart {
            // Spend bars
            ForEach(stats) { s in
                BarMark(
                    x: .value("Month", s.monthStart),
                    y: .value("Spend", s.spend)
                )
                .foregroundStyle(.red.opacity(0.4))
            }

            // Revenue bars
            ForEach(stats) { s in
                BarMark(
                    x: .value("Month", s.monthStart),
                    y: .value("Revenue", s.revenue)
                )
                .foregroundStyle(.green.opacity(0.5))
            }

            // Profit line
            ForEach(stats) { s in
                LineMark(
                    x: .value("Month", s.monthStart),
                    y: .value("Profit", s.profit)
                )
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 3))
                .foregroundStyle(.blue)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisTick()
                AxisGridLine()
                AxisValueLabel(format: .dateTime.year().month(.abbreviated))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartLegend(.automatic)
        .padding(.vertical, 4)
        .overlay {
            if stats.isEmpty {
                ContentUnavailableView("No data yet",
                                       systemImage: "chart.bar.doc.horizontal",
                                       description: Text("Add items and mark some as sold to see monthly profit."))
            }
        }
    }
}

private struct SRPSummaryRow: View {
    let stats: [MonthlyStats]
    var body: some View {
        let spend   = stats.map(\.spend).reduce(0, +)
        let revenue = stats.map(\.revenue).reduce(0, +)
        let profit  = revenue - spend

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Spend", systemImage: "cart")
                Spacer()
                Text(spend, format: .currency(code: "GBP")).foregroundStyle(.red)
            }
            HStack {
                Label("Revenue", systemImage: "sterlingsign.square")
                Spacer()
                Text(revenue, format: .currency(code: "GBP")).foregroundStyle(.green)
            }
            Divider()
            HStack {
                Label("Profit", systemImage: "chart.line.uptrend.xyaxis")
                Spacer()
                Text(profit, format: .currency(code: "GBP"))
                    .foregroundStyle(profit >= 0 ? .green : .red)
                    .fontWeight(.semibold)
            }
        }
        .font(.subheadline)
    }
}

private struct TimeToSellChart: View {
    let points: [DashboardView.TTSEntry]
    var body: some View {
        Chart(points) {
            PointMark(
                x: .value("Sold Date", $0.soldDate),
                y: .value("Days", $0.days)
            )
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.year().month(.abbreviated))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
    }
}
