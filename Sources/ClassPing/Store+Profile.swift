//
//  File:    ~/ClassPing/Sources/ClassPing/Store+Profile.swift
//  Phase:   11a (settings: you, the look, grading and the term)
//  Ports:   the profile writes of app/settings/page.tsx (`handleSave`, the
//           Semester card's `setProfile` calls) and `archiveTerm` in
//           lib/store.tsx
//
//  Summary: Saving your name and picture, the term's name and dates, and
//           "Start a new term", which files this term's classes under its
//           name. Like the grade actions (D-49, D-53), each one only counts
//           once planner.json has it; a failed write puts things back.
//

import Foundation

extension Store {
    /// Your name, saved when you leave the field (the web saves it with the
    /// card's Save button, D-68). A blank name keeps the old one, as the
    /// web's `username.trim() || profile.username` does.
    @discardableResult
    func setUsername(_ name: String) -> Bool {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean != profile.username else { return true }
        let before = profile.username
        profile.username = clean
        save()
        if lastSaveFailed { profile.username = before; return false }
        return true
    }

    /// Your picture as a `data:` address from Logic/Avatar.swift, or nil to
    /// go back to initials. Saved as soon as it's picked (D-68). Anything
    /// that couldn't be shown after a relaunch, or is over the size limit,
    /// is refused.
    @discardableResult
    func setAvatar(_ avatar: String?) -> Bool {
        if let avatar, !isPersistableAvatar(avatar) || avatar.count > AVATAR_MAX_ENCODED_CHARS {
            return false
        }
        let before = profile.avatarURL
        profile.avatarURL = avatar
        save()
        if lastSaveFailed { profile.avatarURL = before; return false }
        return true
    }

    /// The term's name, saved when the field loses focus, as the web saves on
    /// blur. Blank means none; the web's field stops at 64 characters.
    @discardableResult
    func setTermName(_ name: String) -> Bool {
        let clean = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(64))
        let next: String? = clean.isEmpty ? nil : clean
        if next == profile.termName { return true }
        let before = profile.termName
        profile.termName = next
        save()
        if lastSaveFailed { profile.termName = before; return false }
        return true
    }

    /// Sets or clears the semester's first and last days ("yyyy-MM-dd").
    /// A day that isn't real is refused. An end before the start is allowed,
    /// as on the web, and the card says so instead.
    @discardableResult
    func setTermDates(start: String?, end: String?) -> Bool {
        if let start, !isValidDate(start) { return false }
        if let end, !isValidDate(end) { return false }
        let before = (profile.termStart, profile.termEnd)
        profile.termStart = start
        profile.termEnd = end
        save()
        if lastSaveFailed {
            (profile.termStart, profile.termEnd) = before
            return false
        }
        return true
    }

    /// "Start a new term": every class still on the timetable is archived
    /// under `name` (`archiveTerm` in lib/store.tsx), then the term's name and
    /// dates are cleared so the next semester doesn't inherit them, as the
    /// web's Archive button does. Grades stay, now under that past term.
    @discardableResult
    func archiveTerm(_ name: String) -> Bool {
        let label = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty else { return false }
        let beforeCourses = courses
        let beforeProfile = profile
        // `indices` walks the positions, so each class can be changed in place.
        // Deleted classes too, as on the web: one restored from Recently
        // Deleted later belongs to the term it was part of.
        for i in courses.indices where !courses[i].archived {
            courses[i].archived = true
            courses[i].term = label
        }
        profile.termName = nil
        profile.termStart = nil
        profile.termEnd = nil
        save()
        if lastSaveFailed {
            courses = beforeCourses
            profile = beforeProfile
            return false
        }
        return true
    }
}
