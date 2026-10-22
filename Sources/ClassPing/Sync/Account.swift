//
//  File:    ~/ClassPing/Sources/ClassPing/Sync/Account.swift
//  Phase:   14cd (sign-in and sync)
//  Ports:   the web's Clerk setup (ClerkProvider in app/layout.tsx, the
//           Google button of its sign-in page, `useAuth().getToken` in
//           lib/supabase/client.ts, and sign out)
//
//  Summary: Who is signed in, through Clerk's iOS SDK (ClerkKit, vendored by
//           D-96). Signing in opens Google in a secure browser sheet and comes
//           back to the app; Clerk keeps the session in the phone's Keychain.
//           The token it hands out is what Supabase checks on every request.
//

import Foundation
import AuthenticationServices
import ClerkKit

/// The signed-in account, if any, and the sign-in buttons' work. `@Observable`
/// so the Profile tab redraws when you sign in or out; it reads Clerk's own
/// observable state, so a session Clerk restores at launch shows up too.
@MainActor @Observable
final class Account {
    /// Something to show under the button when signing in didn't work, or nil.
    var problem: String? = nil
    /// True while a sign-in or sign-out is running, to stop a second tap.
    var working = false

    /// Sets Clerk up. Call once, before anything asks who is signed in.
    /// `@discardableResult` on Clerk's side means the instance it gives back
    /// can be ignored; `Clerk.shared` finds it again.
    static func configure() {
        Clerk.configure(publishableKey: SyncConfig.clerkPublishableKey)
    }

    /// The signed-in user's Clerk id ("user_..."), which is the `user_id` on
    /// every row of theirs. Nil when signed out.
    var userID: String? { Clerk.shared.user?.id }

    /// The email to show as "Signed in as", when Clerk has one.
    var email: String? { Clerk.shared.user?.primaryEmailAddress?.emailAddress }

    /// True once Clerk has finished checking for a saved session at launch.
    var isLoaded: Bool { Clerk.shared.isLoaded }

    /// Opens Google's sign-in and waits for it. On the web this is the
    /// "Continue with Google" button.
    func signInWithGoogle() async {
        guard !working else { return }
        working = true
        problem = nil
        // `Task { … }.result` runs the throwing call and hands back a
        // `Result` (11a) holding either its answer or its error, which keeps
        // the error without a do/catch block.
        let outcome = await Task {
            try await Clerk.shared.auth.signInWithOAuth(provider: .google)
        }.result
        working = false
        switch outcome {
        case .success(.signIn(let signIn)):
            if signIn.status != .complete { problem = "Sign-in didn't finish. Try again." }
        case .success(.signUp(let signUp)):
            // A Google account that has never used ClassPing gets an account
            // made for it, as on the web. Anything still missing means the
            // account needs a step the phone doesn't offer yet.
            if signUp.status != .complete {
                problem = "Finish creating your account on classping.space, then sign in here."
            }
        case .failure(let error):
            // Closing the Google sheet yourself isn't a problem to report.
            let cancelled = (error as NSError).domain == ASWebAuthenticationSessionErrorDomain
                && (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue
            if !cancelled { problem = "Couldn't sign in: \(error.localizedDescription)" }
        }
    }

    /// Signs out of ClassPing on this phone. Your planner stays on the phone.
    func signOut() async {
        guard !working else { return }
        working = true
        let outcome = await Task { try await Clerk.shared.auth.signOut() }.result
        working = false
        if case .failure(let error) = outcome {
            problem = "Couldn't sign out: \(error.localizedDescription)"
        }
    }

    /// A fresh session token for Supabase, or nil when signed out or it can't
    /// be had. Clerk caches it and refreshes it before it expires;
    /// `skipCache` forces a new one, which is what the web does after a 401.
    /// `static` so the Supabase client can ask without holding an Account.
    static func sessionToken(skipCache: Bool = false) async -> String? {
        var options = Session.GetTokenOptions()
        options.skipCache = skipCache
        return try? await Clerk.shared.auth.getToken(options)
    }
}
