import SwiftUI
import CoreData
import FirebaseCore
import FirebaseAuth

@main
struct YourWardrobeAIApp: App {
    // your Core Data controller if you have one
    let persistenceController = PersistenceController.shared

    @StateObject private var session = AuthSession()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environment(\.managedObjectContext,
                             persistenceController.container.viewContext)
        }
    }
}

/// Observes Firebase auth state
final class AuthSession: ObservableObject {
    @Published var user: User?

    private var handle: AuthStateDidChangeListenerHandle?

    init() {
        handle = Auth.auth().addStateDidChangeListener { _, user in
            self.user = user
        }
    }

    deinit {
        if let h = handle { Auth.auth().removeStateDidChangeListener(h) }
    }

    func signOut() {
        try? Auth.auth().signOut()
    }
}
