import SwiftUI
import FirebaseAuth

struct RootView: View {
    @EnvironmentObject var session: AuthSession

    var body: some View {
        if session.user == nil {
            LoginView()
        } else {
            ContentView() // your existing main UI
        }
    }
}
