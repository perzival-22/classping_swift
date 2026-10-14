//
//  File:    ~/ClassPing/Sources/ClassPing/ClassPingApp.swift
//  Phase:   0 (housekeeping)
//  Ports:   app/layout.tsx (the root that wraps every screen)
//
//  Summary: The app's entry point. It creates the one Store the whole app shares
//           and hands it to every screen through the SwiftUI environment.
//
import SwiftUI

/// @main marks where the app starts, similar to the root layout in the web app
@main
struct ClassPingApp: App {
    /// The app's single store. @State keeps the same store alive for as log as the 
    /// app runs, instead of making a new one everytime SwiftUI redraws
    @State private var store = Store.sample
    var body: some Scene {
        WindowGroup {
            /// '.environment(store)' putrs the store where any screen below can ask for it
            /// with '@Environment(Store.self)' . In the webb app this is the 
            /// <StoreProvider> in lib/store.tsx
            RootView()
                .environment(store)
        }
    }
}
