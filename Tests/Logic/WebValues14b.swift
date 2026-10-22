// WebValues14b.swift: what the web's own functions answered for Phase 14b (instants and feed labels).
// Written by docs/ios/.scratch/p14b/gen.ts (node 24, TZ=America/New_York, a copy of
// lib/supabase/map.ts and the modules it imports, run unchanged). Kelvin does not
// type this file. Every value here is marked "web:" in the tests that read it.

/// web: `Math.floor(Date.parse(text) / 1000)`, or nil where it gives NaN.
let WEB_INSTANTS: [(text: String, seconds: Double?)] = [
    ("2026-09-21T14:13:20.123456+00:00", 1790000000),
    ("2026-09-21T14:13:20+00:00", 1790000000),
    ("2026-09-21T14:13:20Z", 1790000000),
    ("2026-09-21T10:13:20-04:00", 1790000000),
    ("2026-09-21T19:43:20+05:30", 1790000000),
    ("2026-09-21T14:13:20.999Z", 1790000000),
    ("2026-09-21T14:13:20.5+00:00", 1790000000),
    ("2026-09-21 14:13:20+00", 1790000000),
    ("2026-09-21T19:43:20+0530", 1790000000),
    ("2026-09-21T14:13:20", 1790014400),
    ("2026-09-21", 1789948800),
    ("", nil),
    ("garbage", nil),
    ("2026-02-30T00:00:00Z", 1772409600),
    ("2026-09-21T24:00:00Z", 1790035200),
]

/// web: `new Date(seconds * 1000).toISOString()`.
let WEB_ISO: [(seconds: Double, iso: String)] = [
    (0, "1970-01-01T00:00:00.000Z"),
    (1790000000, "2026-09-21T14:13:20.000Z"),
    (1790000000, "2026-09-21T14:13:20.000Z"),
    (1790003600, "2026-09-21T15:13:20.000Z"),
    (951782400, "2000-02-29T00:00:00.000Z"),
]

/// web: `feedLabelFromUrl(url)`.
let WEB_FEED_LABELS: [(url: String, label: String)] = [
    ("https://www.canvas.example.edu/x?token=1", "canvas.example.edu"),
    ("https://Canvas.EXAMPLE.edu/feed.ics", "canvas.example.edu"),
    ("https://", "Calendar feed"),
    ("not a url", "Calendar feed"),
    ("http://localhost:3000/a.ics", "localhost"),
    ("https://user:pw@host.example.edu/x", "host.example.edu"),
]
