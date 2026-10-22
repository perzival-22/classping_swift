//
//  File:    ~/ClassPing/Sources/ClassPing/Sync/WebAPI.swift
//  Phase:   14e (signed-in server calls)
//  Ports:   the `fetch("/api/…")` calls of the web's pages: ImportCalendar.tsx
//           (`loadFeed`), lib/avatar.ts (`uploadAvatar`), the Email switches
//           and `handleDeleteAccount` in app/settings/page.tsx, and
//           components/ReviewCard.tsx
//
//  Summary: Talks to classping.space's own API, signed in. A browser proves
//           who it is with a cookie; the phone sends Clerk's session token as
//           "Authorization: Bearer …" instead, which the web's middleware
//           already accepts (D-103). If the server doesn't take the token,
//           the phone asks Clerk for a fresh one and tries once more, as
//           sync does with Supabase. What the answers mean lives in
//           Logic/WebCalls.swift.
//

import Foundation

/// Refuses to follow redirects. A signed-out request to a protected route is
/// redirected to the sign-in page; following it would come back as "200, a
/// web page", which looks like success. Stopping at the redirect keeps its
/// 3xx status, which `WebReply.tokenRefused` reads as "sign in again".
/// `final` and `Sendable` because URLSession may call it from another thread.
private final class NoRedirects: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest) async -> URLRequest? {
        nil
    }
}

/// The calls. An `enum` with no cases only groups them; there's nothing to make.
enum WebAPI {
    /// The live site. The same origin the web's own pages call.
    static let origin = URL(string: "https://classping.space") ?? URL(fileURLWithPath: "/")

    /// How long to wait before giving up. A feed is fetched by the server
    /// first, so allow it longer than a quick settings call.
    private static let timeout: TimeInterval = 30

    // MARK: Sending

    /// Sends one request, signed in, and gives back what came back. Asks for
    /// a fresh token and tries once more if the first is refused. Nobody
    /// signed in, or no answer at all, gives back status 0 or the refusal.
    static func send(_ method: String, _ path: String, body: JSONValue? = nil) async -> WebReply {
        let first = await attempt(method, path, body: body, freshToken: false)
        guard first.tokenRefused else { return first }
        return await attempt(method, path, body: body, freshToken: true)
    }

    /// One try. `try?` turns a failed request into nil, which becomes status 0.
    private static func attempt(_ method: String, _ path: String, body: JSONValue?,
                                freshToken: Bool) async -> WebReply {
        guard let token = await Account.sessionToken(skipCache: freshToken) else {
            return WebReply(status: 401)
        }
        var request = URLRequest(url: origin.appending(path: path))
        request.httpMethod = method
        request.timeoutInterval = timeout
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONEncoder().encode(body)
        }
        // `.0` and `.1` are the two halves of the (data, response) pair.
        guard let answer = try? await URLSession.shared.data(for: request, delegate: NoRedirects()),
              let http = answer.1 as? HTTPURLResponse else {
            return WebReply(status: 0)
        }
        // A body that isn't JSON (a web page, nothing) is kept as nil.
        let json = try? JSONDecoder().decode(JSONValue.self, from: answer.0)
        return WebReply(status: http.statusCode, body: json)
    }

    // MARK: The five calls

    /// Has the server fetch a calendar feed and read it with the web's own
    /// reader. Nothing is saved there; the phone previews and writes it.
    static func readFeed(_ url: String) async -> WebReply {
        await send("POST", "/api/import/ics", body: .object(["url": .string(url)]))
    }

    /// Uploads a profile photo (a `data:image/…` address) and gives back its
    /// new https address, or nil to keep the photo inside the profile.
    static func uploadAvatar(_ dataURI: String) async -> String? {
        uploadedAvatarURL(await send("POST", "/api/avatar", body: .object(["dataUrl": .string(dataURI)])))
    }

    /// Your email settings.
    static func emailPrefs() async -> WebReply {
        await send("GET", "/api/email/prefs")
    }

    /// Changes email settings. Only the keys in `body` change on the server.
    static func setEmailPrefs(_ body: JSONValue) async -> WebReply {
        await send("PUT", "/api/email/prefs", body: body)
    }

    /// Deletes the account: its server data, its photo and the sign-in itself.
    static func deleteAccount() async -> WebReply {
        await send("DELETE", "/api/account")
    }

    /// Sends a star rating, with an optional comment, to the owner.
    static func sendReview(rating: Int, message: String, name: String) async -> WebReply {
        await send("POST", "/api/feedback", body: reviewBody(rating: rating, message: message, name: name))
    }
}
