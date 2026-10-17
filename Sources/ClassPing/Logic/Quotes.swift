//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/Quotes.swift
//  Phase:   6a (Today: the picked day)
//  Ports:   lib/quotes.ts (DEFAULT_QUOTES, MAX_QUOTES, MAX_QUOTE_CHARS,
//           normalizeQuotes, quoteFor)
//
//  Summary: The motivational line at the top of Today. It changes every two
//           hours, and which one shows is worked out from the clock alone, so
//           the phone and the web app show the same quote at the same moment
//           without syncing anything. Your own list wins over the built-in one.
//

import Foundation

/// The built-in rotation, used until you write your own. `DEFAULT_QUOTES`,
/// word for word, in the same order (the order decides which shows when).
let defaultQuotes = [
    "Small steps every day add up to big results.",
    "You don't have to be perfect, you just have to start.",
    "Focus on progress, not perfection.",
    "The work you do today is a gift to the you of next week.",
    "One page, one problem, one push at a time.",
    "Discipline is choosing what you want most over what you want now.",
    "Done is better than perfect.",
    "Your future self is watching you right now through memories.",
    "A little progress each day beats a burst once a week.",
    "Show up, even when it's just for ten minutes.",
]

/// Ceilings, so a pasted essay can't become the banner. `MAX_QUOTES` and
/// `MAX_QUOTE_CHARS` in lib/quotes.ts.
let maxQuotes = 30
let maxQuoteChars = 200

/// How long each quote stays up: two hours, in seconds. The web counts in
/// milliseconds (`ROTATE_MS`); a Swift `Date` counts in seconds.
private let rotateSeconds: Double = 2 * 60 * 60

/// Cleans up a list of quotes: each one trimmed and cut to 200 characters,
/// blanks dropped, and at most 30 kept. `normalizeQuotes` in lib/quotes.ts.
/// The web also has to throw out things that aren't text at all, because its
/// list can come from anywhere; a Swift `[String]` can only hold text.
func normalizeQuotes(_ raw: [String]) -> [String] {
    // Three steps, chained: tidy each one, drop the empty ones, keep 30.
    // `prefix(n)` takes the first n items (or characters) and never crashes
    // when there are fewer; `Array(...)` turns the result back into a list.
    let tidied = raw.map { String($0.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxQuoteChars)) }
    return Array(tidied.filter { !$0.isEmpty }.prefix(maxQuotes))
}

/// The quote to show at `now`: yours if you have any, else the built-in
/// ones. Empty only if both lists are, which the banner treats as "show
/// nothing". `quoteFor` in lib/quotes.ts.
func quoteFor(_ quotes: [String], _ now: Date) -> String {
    let list = quotes.isEmpty ? defaultQuotes : quotes
    guard !list.isEmpty else { return "" }

    // Which two-hour slot of time `now` is in, counted from 1 January 1970.
    // Every phone and browser agrees on that number, so they agree on the quote.
    let slot = Int((now.timeIntervalSince1970 / rotateSeconds).rounded(.down))

    // The slot picks a quote, wrapping round the list. `%` can come out
    // negative for a negative number, so add the count and take `%` again:
    // the same "positive modulo" the web uses.
    let count = list.count
    return list[((slot % count) + count) % count]
}
