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
import UIKit
import UserNotifications

/// @main marks where the app starts, similar to the root layout in the web app
@main
struct ClassPingApp: App {
    /// UIKit retains the launch delegate for the app's lifetime. It owns the
    /// same store that receives notification taps and drives every screen.
    @UIApplicationDelegateAdaptor(ClassPingAppDelegate.self) private var appDelegate

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
                .environment(appDelegate.store)
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

/// Registers notifications in UIKit's launch lifecycle, before iOS delivers
/// the response that opened the app. The adaptor keeps this object alive.
@MainActor
final class ClassPingAppDelegate: NSObject, UIApplicationDelegate {
    /// One loaded store, shared by notification handling and SwiftUI.
    let store = Store.load()
    private lazy var notificationDelegate = NotificationDelegate(store: store)

    /// Register before launch finishes, including launches from a notification.
    func application(_ application: UIApplication,
                     willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = notificationDelegate
        return true
    }
}

/// Receives iOS callbacks on their notification queue. Read the payload there;
/// only the parsed route crosses to the main actor that owns the store.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    /// The launch delegate's store; never create a second store for a tap.
    let store: Store

    init(store: Store) {
        self.store = store
    }

    /// Keep banners visible while ClassPing is already on screen.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    /// Finish every response, including ignored actions. A default tap queues
    /// its route until RootView is active, even if the screen doesn't exist yet.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping @Sendable () -> Void) {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else {
            completionHandler()
            return
        }
        let destination = notificationRoute(response.notification.request.content.userInfo)
        let store = self.store
        Task { @MainActor in
            store.route = destination
            completionHandler()
        }
    }
}
