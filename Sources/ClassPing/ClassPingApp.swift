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
    /// The app's single store. `@State` keeps the same Store alive for as long as
    /// the app runs, instead of making a new one every time SwiftUI redraws.
    // CHANGED in Phase 1: load what's saved on the phone instead of always the sample.
    @State private var store = Store.load()

    var body: some Scene {
        WindowGroup {
            // `.environment(store)` puts the store where any screen below can ask for it
            // with `@Environment(Store.self)`. In the web app this is the
            // <StoreProvider> in lib/store.tsx.
            RootView()
                .environment(store)
        }
    }
}
