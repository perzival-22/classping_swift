//
//  File:    ~/ClassPing/Sources/ClassPing/Sync/SyncConfig.swift
//  Phase:   14cd (sign-in and sync)
//  Ports:   the three NEXT_PUBLIC_ values in the web's .env (Clerk's
//           publishable key, the Supabase URL and its anon key)
//
//  Summary: Where the app finds the server. These three values are public by
//           design: the web hands the same ones to every browser that opens
//           classping.space, and the server's row-level security, not
//           secrecy, keeps one account from reading another's rows. Nothing
//           else may ever go in this file (IOS_APP.md 3.3): no service-role
//           key, no Clerk secret key.
//

import Foundation

/// The public values sync needs. `enum` with no cases is a common Swift way
/// to group constants: it can't be created by mistake, only read from.
enum SyncConfig {
    /// Clerk's publishable key for the production instance at
    /// clerk.classping.space. The web's NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY.
    static let clerkPublishableKey = "pk_live_Y2xlcmsuY2xhc3NwaW5nLnNwYWNlJA"

    /// The Supabase project. The web's NEXT_PUBLIC_SUPABASE_URL. A literal
    /// that is known to be a valid URL, so the fallback never runs.
    static let supabaseURL = URL(string: "https://hrrcgquguauzyfhgednz.supabase.co")
        ?? URL(fileURLWithPath: "/")

    /// Supabase's anon key: role "anon", which only lets a signed-in user's
    /// token reach that user's own rows. The web's NEXT_PUBLIC_SUPABASE_ANON_KEY.
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhycmNncXVndWF1enlmaGdlZG56Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgyNjYwMzYsImV4cCI6MjEwMzg0MjAzNn0.fyKbN-mGoOqEy1GF6QEDHuP8HB2oyRqh1K5cHeO_rf8"
}
