import Foundation

public struct Field: Identifiable, Hashable {
    public let id = UUID()
    public let label: String
    public let value: String
    public let isSecret: Bool
    init(_ label: String, _ value: String, secret: Bool = false) {
        self.label = label; self.value = value; self.isSecret = secret
    }
}

public struct ParsedPayload: Identifiable {
    public let id = UUID()
    public let raw: String
    public let kind: String
    public let symbol: String          // SF Symbol name
    public let fields: [Field]
    public let actionTitle: String?
    public let actionURL: URL?
}

public enum PayloadParser {
    public static func parse(_ raw: String) -> ParsedPayload {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let upper = text.uppercased()

        if upper.hasPrefix("WIFI:") { return wifi(raw, text) }
        if upper.hasPrefix("MECARD:") { return mecard(raw, text) }
        if upper.hasPrefix("BEGIN:VCARD") { return vcard(raw, text) }
        if upper.hasPrefix("BEGIN:VEVENT") || upper.hasPrefix("BEGIN:VCALENDAR") { return event(raw, text) }
        if upper.hasPrefix("OTPAUTH://") { return otp(raw, text) }
        if upper.hasPrefix("MAILTO:") || upper.hasPrefix("MATMSG:") { return mail(raw, text) }
        if upper.hasPrefix("TEL:") { return phone(raw, text) }
        if upper.hasPrefix("SMSTO:") || upper.hasPrefix("SMS:") { return sms(raw, text) }
        if upper.hasPrefix("GEO:") { return geo(raw, text) }
        if let url = URL(string: text), let scheme = url.scheme?.lowercased(),
           ["http", "https"].contains(scheme), url.host != nil { return web(raw, url) }
        if let data = text.data(using: .utf8),
           text.first == "{" || text.first == "[",
           let obj = try? JSONSerialization.jsonObject(with: data),
           let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
           let s = String(data: pretty, encoding: .utf8) {
            return make(raw, "JSON", "curlybraces", [Field("Content", s)])
        }
        return make(raw, "Text", "text.alignleft", [Field("Content", raw)])
    }

    // MARK: - Types

    private static func web(_ raw: String, _ url: URL) -> ParsedPayload {
        var f = [Field("URL", url.absoluteString), Field("Host", url.host ?? "")]
        if !url.path.isEmpty, url.path != "/" { f.append(Field("Path", url.path)) }
        for item in URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? [] {
            f.append(Field("Param: \(item.name)", item.value ?? ""))
        }
        return make(raw, "Web link", "link", f, "Open in Browser", url)
    }

    private static func wifi(_ raw: String, _ text: String) -> ParsedPayload {
        let p = keyValues(String(text.dropFirst(5)))
        let security = p["T"].flatMap { $0.isEmpty ? nil : $0 } ?? "None"
        var f = [Field("Network", p["S"] ?? ""), Field("Security", security)]
        if let pw = p["P"], !pw.isEmpty { f.append(Field("Password", pw, secret: true)) }
        if p["H"]?.lowercased() == "true" { f.append(Field("Hidden", "Yes")) }
        return make(raw, "Wi‑Fi network", "wifi", f)
    }

    private static func mecard(_ raw: String, _ text: String) -> ParsedPayload {
        let p = keyValues(String(text.dropFirst(7)))
        let names = ["N": "Name", "TEL": "Phone", "EMAIL": "Email", "URL": "URL",
                     "ADR": "Address", "ORG": "Organisation", "NOTE": "Note", "BDAY": "Birthday"]
        let f = names.keys.sorted().compactMap { k in
            p[k].map { Field(names[k]!, k == "N" ? $0.replacingOccurrences(of: ",", with: " ") : $0) }
        }
        return make(raw, "Contact", "person.crop.circle", f)
    }

    private static func vcard(_ raw: String, _ text: String) -> ParsedPayload {
        let names = ["FN": "Name", "ORG": "Organisation", "TITLE": "Title", "TEL": "Phone",
                     "EMAIL": "Email", "URL": "URL", "ADR": "Address", "NOTE": "Note", "BDAY": "Birthday"]
        var f: [Field] = []
        for (prop, value) in contentLines(text) {
            if let label = names[prop] {
                f.append(Field(label, value.replacingOccurrences(of: ";", with: " ")
                    .trimmingCharacters(in: .whitespaces)))
            }
        }
        return make(raw, "Contact (vCard)", "person.crop.circle", f)
    }

    private static func event(_ raw: String, _ text: String) -> ParsedPayload {
        let names = ["SUMMARY": "Title", "DTSTART": "Starts", "DTEND": "Ends",
                     "LOCATION": "Location", "DESCRIPTION": "Description"]
        let f = contentLines(text).compactMap { prop, value in
            names[prop].map { Field($0, value) }
        }
        return make(raw, "Calendar event", "calendar", f)
    }

    private static func otp(_ raw: String, _ text: String) -> ParsedPayload {
        guard let c = URLComponents(string: text) else { return make(raw, "One-time password", "key", [Field("Content", raw)]) }
        var f = [Field("Type", (c.host ?? "").uppercased()),
                 Field("Account", c.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))]
        for item in c.queryItems ?? [] {
            f.append(Field(item.name.capitalized, item.value ?? "", secret: item.name == "secret"))
        }
        return make(raw, "One-time password (2FA)", "key", f)
    }

    private static func mail(_ raw: String, _ text: String) -> ParsedPayload {
        var f: [Field] = []
        var url: URL?
        if text.uppercased().hasPrefix("MATMSG:") {
            let p = keyValues(String(text.dropFirst(7)))
            f = [Field("To", p["TO"] ?? ""), Field("Subject", p["SUB"] ?? ""), Field("Body", p["BODY"] ?? "")]
                .filter { !$0.value.isEmpty }
        } else if let c = URLComponents(string: text) {
            f.append(Field("To", c.path))
            for q in c.queryItems ?? [] { f.append(Field(q.name.capitalized, q.value ?? "")) }
            url = URL(string: text)
        }
        return make(raw, "Email", "envelope", f, url == nil ? nil : "Compose Email", url)
    }

    private static func phone(_ raw: String, _ text: String) -> ParsedPayload {
        make(raw, "Phone number", "phone", [Field("Number", String(text.dropFirst(4)))])
    }

    private static func sms(_ raw: String, _ text: String) -> ParsedPayload {
        let body = String(text.drop { $0 != ":" }.dropFirst())
        let parts = body.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        var number = String(parts.first ?? "")
        var message = parts.count > 1 ? String(parts[1]) : ""
        if let q = number.firstIndex(of: "?") {   // sms:+123?body=hi
            let query = number[number.index(after: q)...]
            message = query.split(separator: "&").first { $0.hasPrefix("body=") }
                .map { String($0.dropFirst(5)).removingPercentEncoding ?? "" } ?? message
            number = String(number[..<q])
        }
        return make(raw, "SMS", "message", [Field("To", number), Field("Message", message)].filter { !$0.value.isEmpty })
    }

    private static func geo(_ raw: String, _ text: String) -> ParsedPayload {
        let coords = text.dropFirst(4).split(separator: "?").first.map(String.init) ?? ""
        let url = URL(string: "https://maps.apple.com/?ll=\(coords)")
        return make(raw, "Location", "mappin.and.ellipse", [Field("Coordinates", coords)], "Open in Maps", url)
    }

    // MARK: - Helpers

    private static func make(_ raw: String, _ kind: String, _ symbol: String, _ fields: [Field],
                             _ actionTitle: String? = nil, _ actionURL: URL? = nil) -> ParsedPayload {
        ParsedPayload(raw: raw, kind: kind, symbol: symbol, fields: fields,
                      actionTitle: actionTitle, actionURL: actionURL)
    }

    /// Parses `KEY:value;KEY:value;;` honouring backslash escapes (`\;`, `\:`, `\\`, `\,`).
    static func keyValues(_ s: String) -> [String: String] {
        var result: [String: String] = [:]
        var current = ""
        var parts: [String] = []
        var escaped = false
        for ch in s {
            if escaped { current.append(ch); escaped = false }
            else if ch == "\\" { escaped = true }
            else if ch == ";" { parts.append(current); current = "" }
            else { current.append(ch) }
        }
        parts.append(current)
        for part in parts {
            guard let i = part.firstIndex(of: ":") else { continue }
            result[String(part[..<i]).uppercased()] = String(part[part.index(after: i)...])
        }
        return result
    }

    /// vCard / iCalendar content lines as (PROPERTY, value), ignoring parameters like `;TYPE=WORK`.
    static func contentLines(_ s: String) -> [(String, String)] {
        s.components(separatedBy: .newlines).compactMap { line in
            guard let colon = line.firstIndex(of: ":") else { return nil }
            let prop = line[..<colon].split(separator: ";").first.map { String($0).uppercased() } ?? ""
            let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            return value.isEmpty ? nil : (prop, value)
        }
    }
}
