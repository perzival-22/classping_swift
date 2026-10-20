//
//  File:    ~/ClassPing/Sources/ClassPing/Profile.swift
//  Phase:   1 (complete data models)
//  Ports:   lib/store.tsx (Profile), lib/accents.ts, lib/feeds.ts (SavedFeed),
//           lib/gpa.ts (ScaleBand), lib/supabase/map.ts (profiles row)
//
//  Summary: Your preferences: name, theme, accent, quiet hours, term dates,
//           grade scale, saved calendar feeds and your own quotes.
//

import Foundation

//One saved Calender feed
struct SavedFeed: Identifiable, Codable, Hashable {
    var id = UUID()
    var url: String
    var label: String
    var lastSyncedAt: Date? = nil 
}

// Phase 9a: ScaleBand now lives in Logic/GPA.swift so Linux logic tests can
// use it too. Its Codable fields have not changed; old profiles still load.

struct Profile: Codable, Hashable {
    //Theme ligh or dark
    enum Theme: String, Codable {case light, dark}

    //App-wide accent
    enum Accent: String, Codable, CaseIterable { case babypink, ocean}

    //Letter-grade scale

    enum GradeScale: String, Codable {case standard, simple, custom}

    //who the user is
    var username = ""
    var avatarURL: String? = nil

    // How the app looks.
    var theme = Theme.light
    var accent = Accent.babypink    // Baby Pink is the default

    // Reminders.
    var postClassNudge = true       // "Did that class come with homework?"
    var quietStart: Int? = nil      // minutes from midnight; both nil = never quiet
    var quietEnd: Int? = nil

    // The term.
    var finalsDate: String? = nil   // "yyyy-MM-dd"
    var gradeScale: GradeScale? = nil
    var termStart: String? = nil
    var termEnd: String? = nil
    var termName: String? = nil     // "Fall 2026"
    var termSetupPrompted = false

    // Lists you build up.
    var importFeeds: [SavedFeed] = []   // at most 5
    var customScale: [ScaleBand] = []   // at most 16, used when gradeScale is .custom
    var quotes: [String] = []           // empty = the built-in quotes
}
