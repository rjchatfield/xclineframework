import Foundation

public struct Line {
    let string: String
    public internal(set) var start: Int
    public internal(set) var end: Int

    var startIndex: String.Index {
        get { string.safeIndex(offset: start)! }
        set { start = string.distance(from: string.startIndex, to: newValue) }
    }

    var endIndex: String.Index {
        get { string.safeIndex(offset: end)! }
        set { end = string.distance(from: string.startIndex, to: newValue) }
    }

    public init(string: String, startColumn: Int, endColumn: Int) {
        self.string = string
        self.start = startColumn
        self.end = endColumn
    }
}

// MARK: - RAW Representation

extension Line {
    typealias Raw = (before: Substring, selected: Substring, after: Substring)

    @_spi(Testing)
    public init(testString: String) {
        let raw = makeRaw(testString)!
        string = String(raw.before + raw.selected + raw.after)
        start = raw.before.count
        end = raw.before.count + raw.selected.count
    }
    
    @_spi(Testing)
    public var rawDescription: String {
        let raw: Raw = string.partition(start: start, end: end)
        return "\(raw.before)|\(raw.selected)|\(raw.after)"
    }
}

// MARK: - Equatable

extension Line: Equatable {
    public static func == (lhs: Line, rhs: Line) -> Bool {
        return lhs.start == rhs.start
            && lhs.end == rhs.end
            && lhs.string == rhs.string
    }
}

func makeRaw(_ string: String) -> Line.Raw? {
    guard let firstDividerIndex = string.firstIndex(of: "|") else { return nil }
    let beforeFirstDivider = string.prefix(upTo: firstDividerIndex)
    let afterFirstDivider = string[string.index(after: firstDividerIndex)...]
    if let secondDivider = afterFirstDivider.firstIndex(of: "|") {
        return (
            beforeFirstDivider,
            afterFirstDivider[..<secondDivider],
            afterFirstDivider[afterFirstDivider.index(after: secondDivider)...]
        )
    } else {
        return (
            beforeFirstDivider,
            "",
            afterFirstDivider
        )
    }
}
