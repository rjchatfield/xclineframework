import Foundation

public struct Line {
    public var chars: String.UnicodeScalarView
    public var start: Int
    public var end: Int
}

extension Line {
    public typealias Raw = (before: String, selected: String, after: String)
    public init(string: String, start: Int, end: Int) {
        self.chars = string.unicodeScalars
        self.start = start
        self.end = end
    }
    public init(raw: Raw) {
        self.chars = (raw.before + raw.selected + raw.after).unicodeScalars
        self.start = raw.before.characters.count
        self.end = raw.before.characters.count + raw.selected.characters.count
    }
    public init?(string: String) {
        guard let raw = makeRaw(string) else { return nil }
        self.init(raw: raw)
    }
    public var string: String {
        return String(describing: chars)
    }
    public var raw: Raw {
        return String(describing: chars).partition(start: start, end: end)
    }
    var startIndex: String.UnicodeScalarView.Index {
        return chars.index(chars.startIndex, offsetBy: start)
    }
    var endIndex: String.UnicodeScalarView.Index {
        return chars.index(chars.startIndex, offsetBy: end)
    }
    var selectedChars: String.UnicodeScalarView {
        return chars[startIndex..<endIndex]
    }
    var startChars: String.UnicodeScalarView {
        return chars[chars.startIndex..<startIndex]
    }
    var endChars: String.UnicodeScalarView {
        return chars[endIndex..<chars.endIndex]
    }
}

public func makeRaw(_ string: String) -> Line.Raw? {
    var chars = string.unicodeScalars
    guard let first = chars.index(of: "|") else { return nil }
    let before = String(chars.prefix(upTo: first))
    chars = chars[chars.index(after: first)..<chars.endIndex]
    if let second = chars.index(of: "|") {
        return (
            before,
            String(chars.prefix(upTo: second)),
            String(chars[chars.index(after: second)..<chars.endIndex])
        )
    } else {
        return (
            before,
            "",
            String(chars)
        )
    }
}
