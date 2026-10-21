//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/JSONValue.swift
//  Phase:   11b+c (backups, Recently Deleted and the calendar)
//  Ports:   nothing on its own: it's how Swift holds the `unknown` values
//           lib/backup.ts reads before it trusts them
//
//  Summary: One type that can hold anything a JSON file holds: nothing,
//           true/false, a number, text, a list or a set of named values. A
//           backup file is read into this first, checked, and only then
//           turned into classes and assignments. Foundation only.
//

import Foundation

/// Any JSON value. The web reads a backup with `JSON.parse`, which gives back
/// `unknown`, and then checks each piece (`typeof x === "string"`). Swift has
/// no `unknown`, so this enum is the stand-in: each case is one kind of JSON
/// value and carries the value itself. A list holds more `JSONValue`s and an
/// object maps names to them, so one value can describe a whole file.
///
/// Hashable gives `==`, which compares two values piece by piece. Two
/// objects with the same names and values are equal whatever order the file
/// wrote them in. Sendable means it can be handed between threads safely.
enum JSONValue: Codable, Hashable, Sendable {
    case null
    case bool(Bool)
    case number(Double)       // JSON has one number type; so does JavaScript
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    /// Reads one value of any kind. `Codable` asks for an `init(from:)` that
    /// may throw, but a version that never throws is allowed to stand in for
    /// it, so there's no `do`/`catch` here. Each `try?` attempt either gives
    /// a value or nil, and the first kind that fits wins. Bool goes first
    /// because a JSON `true` must never be read as the number 1.
    init(from decoder: any Decoder) {
        guard let box = try? decoder.singleValueContainer() else {
            self = .null
            return
        }
        if box.decodeNil() {
            self = .null
        } else if let flag = try? box.decode(Bool.self) {
            self = .bool(flag)
        } else if let number = try? box.decode(Double.self) {
            self = .number(number)
        } else if let text = try? box.decode(String.self) {
            self = .string(text)
        } else if let list = try? box.decode([JSONValue].self) {
            self = .array(list)
        } else if let object = try? box.decode([String: JSONValue].self) {
            self = .object(object)
        } else {
            self = .null
        }
    }

    /// Writes the value back out, the same way round: never throws, and a
    /// value the encoder refuses (it won't happen for these kinds) is left out.
    func encode(to encoder: any Encoder) {
        var box = encoder.singleValueContainer()
        switch self {
        case .null: try? box.encodeNil()
        case .bool(let flag): try? box.encode(flag)
        case .number(let number): try? box.encode(number)
        case .string(let text): try? box.encode(text)
        case .array(let list): try? box.encode(list)
        case .object(let object): try? box.encode(object)
        }
    }
}

// MARK: - Reading a value

extension JSONValue {
    /// The value under `key` when this is an object, otherwise nil. Lets the
    /// readers write `item["title"]`, like the web's `t.title`.
    subscript(key: String) -> JSONValue? {
        guard case .object(let object) = self else { return nil }
        return object[key]
    }

    /// The text, when this is text. `typeof v === "string" ? v : …`.
    /// `if case` checks one case of an enum and pulls its value out.
    var stringValue: String? {
        if case .string(let text) = self { return text }
        return nil
    }

    /// The number, when this is a number that isn't infinity or NaN.
    /// `Number.isFinite(v)` on the web.
    var numberValue: Double? {
        if case .number(let number) = self, number.isFinite { return number }
        return nil
    }

    /// The number when it's a whole one, like `Number.isInteger(v)`:
    /// 600 gives 600, 600.5 and "600" give nil. `Int(exactly:)` refuses
    /// anything with a fraction or too big for an Int.
    var intValue: Int? {
        numberValue.flatMap { Int(exactly: $0) }
    }

    /// true or false, when this is one. `v === true` is `boolValue == true`.
    var boolValue: Bool? {
        if case .bool(let flag) = self { return flag }
        return nil
    }

    /// The list, when this is one. `Array.isArray(v) ? v : …`.
    var arrayValue: [JSONValue]? {
        if case .array(let list) = self { return list }
        return nil
    }

    /// The named values, when this is an object (not a list, not null).
    /// The web's `isObj`.
    var objectValue: [String: JSONValue]? {
        if case .object(let object) = self { return object }
        return nil
    }
}

// MARK: - Making a value

extension JSONValue {
    /// A whole number as a JSON number: `.int(600)`. Lists of numbers read
    /// well this way: `days.map(JSONValue.int)`.
    static func int(_ number: Int) -> JSONValue {
        .number(Double(number))
    }
}
