import Foundation

public struct Line {
    public var chars: String.UnicodeScalarView
    public var start: Int
    public var end: Int
}

extension Line {
    typealias Raw = (before: String, selected: String, after: String)
    public init(string: String, start: Int, end: Int) {
        self.chars = string.unicodeScalars
        self.start = start
        self.end = end
    }
    init(raw: Raw) {
        self.chars = (raw.before + raw.selected + raw.after).unicodeScalars
        self.start = raw.before.characters.count
        self.end = raw.before.characters.count + raw.selected.characters.count
    }
    var string: String {
        return String(describing: chars)
    }
    var raw: Raw {
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
