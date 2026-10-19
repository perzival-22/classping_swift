//
//  File:    ~/ClassPing/Sources/ClassPing/ClassPingApp.swift
//  Phase:   0 (housekeeping), changed in 7a (reminders) and 7c (taps)
//  Ports:   app/layout.tsx (the root that wraps every screen), when the
//           reminder loop in lib/store.tsx runs, and the notificationclick
//           handler in public/sw.js
//
//  Summary: The app's entry point. It creates the one Store the whole app
//           shares and hands it to every screen through the SwiftUI
//           environment. Since 7a it also keeps iOS's reminders in step with
//           the store, and lets them show while the app is open. Since 7c a
//           tap on one tells the store where to go.
//
import SwiftUI
import UserNotifications   // NEW in Phase 7a

/// @main marks where the app starts, similar to the root layout in the web app
@main
struct ClassPingApp: App {
    /// The app's single store. `@State` keeps the same Store alive for as long as
    /// the app runs, instead of making a new one every time SwiftUI redraws.
    // CHANGED in Phase 1: load what's saved on the phone instead of always the sample.
    // CHANGED in Phase 7c: loaded in `init`, so the delegate can share it.
    @State private var store: Store

    /// NEW in Phase 7a: the object iOS calls about notifications: before
    /// showing one while the app is open, and (since 7c) when you tap one.
    /// iOS only holds on to it weakly (it won't keep it alive by itself), so
    /// the app keeps it here for as long as it runs.
    // CHANGED in Phase 7c: made in `init`, with the store.
    private let notificationDelegate: NotificationDelegate

    /// NEW in Phase 7a: runs once, as the app starts, so the delegate is in
    /// place before any notification can arrive. iOS needs it set before the
    /// app finishes launching, or a tap that launched the app would be lost.
    // CHANGED in Phase 7c: loads the store here and hands the delegate the
    // same one. `_store` is the State box itself (as in 4a's form init).
    init() {
        let loaded = Store.load()
        _store = State(initialValue: loaded)
        notificationDelegate = NotificationDelegate(store: loaded)
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            // `.environment(store)` puts the store where any screen below can ask for it
            // with `@Environment(Store.self)`. In the web app this is the
            // <StoreProvider> in lib/store.tsx.
            // CHANGED in Phase 7a: `.modifier(ReminderSync())` keeps the
            // reminders up to date. It sits inside `.environment(store)`, so
            // it can read the store too.
            RootView()
                .modifier(ReminderSync())
                .environment(store)
        }
    }
}

/// Rebuilds the reminder plan when the app starts, whenever your classes,
/// work or reminder settings change, and whenever the app comes back to the
/// screen. The web runs its check every 30 seconds while a tab is open; the
/// phone only needs to when something changed. A `ViewModifier`, like 4b's
/// Undo bar, because it needs the environment and a piece of state.
// NEW in Phase 7a
private struct ReminderSync: ViewModifier {
    @Environment(Store.self) private var store

    /// Whether the app is on screen (`.active`), half-covered (`.inactive`,
    /// say while Notification Center is pulled down) or in the background.
    /// SwiftUI keeps it up to date.
    @Environment(\.scenePhase) private var scenePhase

    /// How many times the app has come back to the screen. Each return bumps
    /// it, which re-runs the sync: a new day's nudges get planned, and what
    /// rang in the meantime is crossed off.
    @State private var wakeUps = 0

    func body(content: Content) -> some View {
        content
            // `.task(id:)` (4b) runs this when the app starts, and again,
            // cancelling the old run first, every time the id changes.
            .task(id: Trigger(inputs: store.reminderInputs, wakeUps: wakeUps)) {
                // Wait a moment, so a burst of quick edits (ticking off three
                // tasks) makes one sync, not three. A newer edit cancels the
                // wait; `try?` ignores that cancellation, and the guard stops.
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                await store.syncReminders()
            }
            // Count each return to the screen.
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { wakeUps += 1 }
            }
    }

    /// What the sync watches: the store's reminder inputs plus the wake-up
    /// count. Equatable, so `.task(id:)` can tell when it changed.
    private struct Trigger: Equatable {
        let inputs: Store.ReminderInputs
        let wakeUps: Int
    }
}

/// Lets reminders show while ClassPing is open, and (since 7c) opens the
/// right screen when you tap one. Without it, iOS stays silent about a
/// notification that arrives while you're in the app (the web shows them
/// while it's open, the only time it can). A delegate is an object iOS calls
/// back with "this is happening, what should I do?". `NSObject` is the base
/// class Apple's older callback-based frameworks expect.
// NEW in Phase 7a
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    /// NEW in Phase 7c: the app's store, where a tap leaves its route. A `let`,
    /// set once. The store is `@MainActor`, so holding it from here is safe;
    /// changing it means going over to the main actor first (below).
    let store: Store

    /// NEW in Phase 7c
    init(store: Store) {
        self.store = store
    }

    /// A notification is arriving with the app on screen: show it anyway, as
    /// a banner with its sound, and keep it in Notification Center.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification)
        async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    /// NEW in Phase 7c: you tapped a notification, on the lock screen, in
    /// Notification Center or as a banner. If the app was closed, iOS opens
    /// it first, then calls this. The web's `notificationclick` in sw.js.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        // Only a plain tap opens a screen. (Other answers, like dismissing,
        // only arrive here if an app asks for them; ClassPing doesn't.)
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else { return }
        // Where to go, read from what 7a attached (Logic/PostClass.swift).
        let destination = notificationRoute(response.notification.request.content.userInfo)

        // This method doesn't run on the main actor, and the store lives
        // there. `MainActor.run` hops over, runs the closure, and comes back
        // (`await` waits for it). The closure may only take along values that
        // are safe to send between actors: the store and the route are, `self`
        // (a plain NSObject) isn't, so the store is copied into a local first.
        let store = self.store
        await MainActor.run {
            store.route = destination
        }
    }
}
