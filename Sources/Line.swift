import Foundation

public struct Line {
    let string: String
    public internal(set) var start: Int {
        didSet {
            _startIndex = nil
            _selectedChars = nil
            _startChars = nil
        }
    }
    public internal(set) var end: Int {
        didSet {
            _endIndex = nil
            _selectedChars = nil
            _endChars = nil
        }
    }
    
    public init(string: String, startColumn: Int, endColumn: Int) {
        self.string = string
        self.start = startColumn
        self.end = endColumn
    }
    
    // CACHED VALUES
    private var _startIndex: String.Index?
    private var startIndex: String.Index {
        mutating get {
            if _startIndex == nil {
                _startIndex = string.index(start) ?? string.endIndex
            }
            return _startIndex!
        }
    }
    private var _endIndex: String.Index?
    private var endIndex: String.Index {
        mutating get {
            if _endIndex == nil {
                _endIndex = string.index(end) ?? string.endIndex
            }
            return _endIndex!
        }
    }
    
    private var _selectedChars: Substring?
    var selectedChars: Substring {
        mutating get {
            if _selectedChars == nil {
                _selectedChars = string[startIndex..<endIndex]
            }
            return _selectedChars!
        }
    }
    private var _startChars: Substring?
    var startChars: Substring {
        mutating get {
            if _startChars == nil {
                _startChars = string[..<startIndex]
            }
            return _startChars!
        }
    }
    private var _endChars: Substring?
    var endChars: Substring {
        mutating get {
            if _endChars == nil {
                _endChars = string[endIndex...]
            }
            return _endChars!
        }
    }
}

// MARK: - RAW Representation

extension Line {
    
    fileprivate typealias Raw = (before: Substring, selected: Substring, after: Substring)
    
    init(testString: String) {
        let raw = makeRaw(testString)!
        string = String(raw.before + raw.selected + raw.after)
        start = raw.before.count
        end = raw.before.count + raw.selected.count
    }
    
    var rawDescription: String {
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

private func makeRaw(_ string: String) -> Line.Raw? {
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
