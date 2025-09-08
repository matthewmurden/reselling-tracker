//
//  YourWardrobeAIApp.swift
//  YourWardrobeAI
//
//  Created by Matt murden on 08/09/2025.
//

import SwiftUI

@main
struct YourWardrobeAIApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
