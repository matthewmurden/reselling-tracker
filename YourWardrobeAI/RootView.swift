import SwiftUI
import FirebaseAuth

struct RootView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var session: AuthSession

    @State private var selectedTab = 0

    var body: some View {
        Group {
            if session.user != nil {
                TabView(selection: $selectedTab) {
                    ContentView()
                        .tabItem { Label("Items", systemImage: "list.bullet.rectangle") }
                        .tag(0)

                    // New analytics dashboard
                    DashboardView()
                        .tabItem { Label("Dashboard", systemImage: "chart.bar.xaxis") }
                        .tag(1)
                }
                .environment(\.managedObjectContext, viewContext)
            } else {
                NavigationStack {
                    LoginView()
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
        .onChange(of: session.user) { user in
            if user == nil { selectedTab = 0 }
        }
    }
}
