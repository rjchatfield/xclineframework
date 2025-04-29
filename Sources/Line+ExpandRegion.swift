import Foundation

extension Line {
    public func expandedRegion() -> Line {
        var result = self
        result.untrimSelection()
        result.expand()
        result.trimSelection()
        return result
    }
    
    func log(f: String = #function) {
        #if DEBUG
            print("❣️", rawDescription.replacingOccurrences(of: "\n", with: ""), "\t", f)
        #endif
    }
}

private extension Line {
    // MARK: -  Methods

    mutating func untrimSelection() {
        defer { log() }
        let reversedStartChars = startChars.reversed()
        if let startTrim = reversedStartChars.firstIndex(where: CharacterSet.whitespacesAndNewlines.doesNotContain) {
            let dist = reversedStartChars.distance(from: reversedStartChars.startIndex, to: startTrim)
            if dist <= start {
                start -= dist
            }
        }
        if let endTrim = endChars.firstIndex(where: CharacterSet.whitespacesAndNewlines.doesNotContain) {
            let dist = endChars.distance(from: endChars.startIndex, to: endTrim)
            if dist < string.count - end {
                end += dist
            }
        }
    }

    mutating func expand() {
        if couldBeInAWord {
            self = expandedToWord()
        } else if boundariesMatch {
            self = expandedToIncludeBoundaries()
        } else {
            self = expandedBeyondBoundaries()
        }
    }

    mutating func trimSelection() {
        defer { log() }
        if let startTrim = selectedChars.firstIndex(where: CharacterSet.whitespacesAndNewlines.doesNotContain) {
            let dist = selectedChars.distance(from: selectedChars.startIndex, to: startTrim)
            let newStart = start + dist
            if newStart <= end {
                start = newStart
            }
        }
        let reversedSelectedChars = selectedChars.reversed()
        if let endTrim = reversedSelectedChars.firstIndex(where: CharacterSet.whitespacesAndNewlines.doesNotContain) {
            let dist = reversedSelectedChars.distance(from: reversedSelectedChars.startIndex, to: endTrim)
            let newEnd = end - dist
            if newEnd >= start {
                end = newEnd
            }
        }
    }

    // MARK: - Status properties

    private var selectedChars: Substring { string[startIndex..<endIndex] }
    private var startChars: Substring { string[..<startIndex] }
    private var endChars: Substring { string[endIndex...] }

    /// Check that both next and previous are not boundaries yet
    private var couldBeInAWord: Bool {
        guard selectedChars.doesNotContain(anyOf: .allBoundariesAndSpace),
              let beforeBoundary = startChars.last,
              let afterBoundary = endChars.first
        else {
            return false
        }
        return beforeBoundary.isNotContained(in: .allBoundariesAndSpace)
            || afterBoundary.isNotContained(in: .allBoundariesAndSpace)
    }

    private var couldBeInAParam: Bool {
        if trailingBoundary == ":" { return false }
        if startChars.doesNotContain(anyOf: .colon) { return false }
        if leadingBoundary?.isContained(in: CharacterSet.colon.union(.comma)) == true,
            trailingBoundary?.isContained(in: CharacterSet.rightBoundaries.union(.comma)) == true { return false }
        if leadingBoundary?.isContained(in: .leftBoundaries) == true { return false }
        return true
    }

    private var couldBeInAPair: Bool {
        if let leadingBoundary,
           let trailingBoundary,
           leadingBoundary.isContained(in: CharacterSet.leftBoundaries.union(.comma)),
           trailingBoundary.isContained(in: CharacterSet.rightBoundaries.union(.comma)) {
            return false
        }
        return true
    }

    private var couldBeInAString: Bool {
        if selectedChars.contains(anyOf: .quotes) { return false }
        if startChars.contains(anyOf: .quotes) && endChars.contains(anyOf: .quotes) { return true }
        return false
    }

    private var hasNoStartBoundaryToParse: Bool { start <= 0 }

    private var hasNoEndBoundaryToParse: Bool { end >= string.count }
    
    // MARK: - Mutations

    private func expandedToWord() -> Line {
        var line = self
        defer { line.log() }
        line.startIndex = startChars.reversed().firstIndex(in: .allBoundariesAndSpace)?.base ?? string.startIndex
        line.endIndex = endChars.firstIndex(in: .allBoundariesAndSpace) ?? string.endIndex
        return line
    }

    private func expandedToIncludeBoundaries() -> Line {
        var line = self
        defer { line.log() }
        line.start -= 1
        line.end += 1
        return line
    }

    private func expandedBeyondBoundaries() -> Line {
        var remaining = self
        defer { remaining.log() }
        var willExpandToQuotes = true
        var willExpandToComma = true
        var willExpandToColon = true
        repeat {
            if willExpandToQuotes && !couldBeInAString { willExpandToQuotes = false }
            if willExpandToComma && !couldBeInAPair { willExpandToComma = false }
            if willExpandToColon && !couldBeInAParam { willExpandToColon = false }
            let (expandedLine, finished) = remaining.expandedToBoundary(includeQuotes: willExpandToQuotes, includeComma: willExpandToComma, includeColon: willExpandToColon)
            if finished { return expandedLine }
            remaining = expandedLine
            remaining.log()
        } while !remaining.hasNoStartBoundaryToParse || !remaining.hasNoEndBoundaryToParse
        return remaining
    }

    private func expandedToBoundary(includeQuotes: Bool, includeComma: Bool, includeColon: Bool) -> (Line, finished: Bool) {
        var line = self
        defer { line.log() }
        line.end = line.findNextTrailingBoundary(includeQuotes: includeQuotes, includeComma: includeComma, includeColon: includeColon)
        line.start = line.findPreviousLeadingBoundary(includeQuotes: includeQuotes, includeComma: includeComma, includeColon: includeColon)
        if line.hasNoStartBoundaryToParse && line.hasNoEndBoundaryToParse { return (line, true) }
        if line.boundariesMatch { return (line, true) }
        switch line.compareBoundaries(includeQuotes: includeQuotes, includeComma: includeComma, includeColon: includeColon) {
        case .orderedSame: return (line, true)
        case .orderedAscending: if line.start > 0 { line.start -= 1 } else { return (line, true) }
        case .orderedDescending: if line.end < line.string.count { line.end += 1 } else { return (line, true) }
        }
        return (line, false)
    }
    
    // MARK: - Boundaries
    
    private var leadingBoundary: Character? {
        guard start > 0 else { return nil }
        guard let index = string.index(string.startIndex, offsetBy: start - 1, limitedBy: string.endIndex) else { return nil }
        return string[index]
    }

    private var trailingBoundary: Character? {
        guard end < string.count else { return nil }
        guard let index = string.index(string.startIndex, offsetBy: end, limitedBy: string.endIndex) else { return nil }
        return string[index]
    }

    private var boundariesMatch: Bool {
        guard let leadingBoundary,
              let trailingBoundary,
              let matches = rules[leadingBoundary]
        else { return false }
        return CharacterSet(charactersIn: matches).contains(trailingBoundary)
    }

    private func findPreviousLeadingBoundary(includeQuotes: Bool, includeComma: Bool, includeColon: Bool) -> Int {
        let reversedStartChars = startChars.reversed()
        var boundaries = CharacterSet.leftBoundaries
        if includeQuotes { boundaries = boundaries.union(.quotes) }
        if includeComma { boundaries = boundaries.union(.comma) }
        if includeColon { boundaries = boundaries.union(.colon) }
        if let i = reversedStartChars.indexOf(cond: boundaries.contains, ignoringConds: IgnoringCondition.flippedCases) {
            return start - reversedStartChars.distance(from: reversedStartChars.startIndex, to: i)
        }
        return 0
    }

    private func findNextTrailingBoundary(includeQuotes: Bool, includeComma: Bool, includeColon: Bool) -> Int {
        var boundaries = CharacterSet.rightBoundaries
        if includeQuotes { boundaries = boundaries.union(.quotes) }
        if includeComma { boundaries = boundaries.union(.comma) }
        if includeColon { boundaries = boundaries.union(.colon) }
        if let i = endChars.indexOf(cond: boundaries.contains, ignoringConds: IgnoringCondition.allCases) {
            return end + endChars.distance(from: endChars.startIndex, to: i)
        }
        return string.unicodeScalars.count
    }

    private func compareBoundaries(includeQuotes: Bool, includeComma: Bool, includeColon: Bool) -> ComparisonResult {
        switch (leadingBoundary, trailingBoundary) {
        case (nil, nil): return .orderedSame
        case (_?, nil): return .orderedAscending
        case (nil, _?): return .orderedDescending
        case let (lhs?, rhs?):
            let left = leftBoundaryScore(lhs, includeQuotes: includeQuotes, includeComma: includeComma, includeColon: includeColon)
            let right = rightBoundaryScore(rhs, includeQuotes: includeQuotes, includeComma: includeComma, includeColon: includeColon)
            if left == right { return .orderedSame }
            else if left > right { return .orderedDescending }
            else { return .orderedAscending }
        }
    }

    private static func boundaries(major: CharacterSet, includeQuotes: Bool, includeComma: Bool, includeColon: Bool) -> (CharacterSet, CharacterSet) {
        var majorBoundaries = major
        var minorBoundaries = CharacterSet.quotes
        if includeComma {
            majorBoundaries = majorBoundaries.union(.comma)
        } else {
            minorBoundaries = minorBoundaries.union(.comma)
        }
        if includeColon {
            majorBoundaries = majorBoundaries.union(.colon)
        }
        return (majorBoundaries, minorBoundaries)
    }

    private func leftBoundaryScore(_ x: Character, includeQuotes: Bool, includeComma: Bool, includeColon: Bool) -> Int {
        let (majorBoundaries, minorBoundaries) = Line.boundaries(major: .leftBoundaries, includeQuotes: includeQuotes, includeComma: includeComma, includeColon: includeColon)
        if majorBoundaries.contains(x) { return 2 }
        if minorBoundaries.contains(x) { return 1 }
        return 0
    }

    private func rightBoundaryScore(_ x: Character, includeQuotes: Bool, includeComma: Bool, includeColon: Bool) -> Int {
        let (majorBoundaries, minorBoundaries) = Line.boundaries(major: .rightBoundaries, includeQuotes: includeQuotes, includeComma: includeComma, includeColon: includeColon)
        if majorBoundaries.contains(x) { return 2 }
        if minorBoundaries.contains(x) { return 1 }
        return 0
    }
}

private struct IgnoringCondition {
    let startChar: Character
    let stopChar: Character
    func shouldStart(_ char: Character) -> Bool { char == startChar }
    func shouldStop(_ char: Character) -> Bool { char == stopChar }

    var flipped: Self { .init(startChar: stopChar, stopChar: startChar) }

    static let allCases: [IgnoringCondition] = [
        IgnoringCondition(startChar: "[", stopChar: "]"),
        IgnoringCondition(startChar: "{", stopChar: "}"),
        IgnoringCondition(startChar: "<", stopChar: ">"),
        IgnoringCondition(startChar: "(", stopChar: ")"),
    ]

    static let flippedCases: [IgnoringCondition] = allCases.map(\.flipped)
}


private let rules: [Character: String] = [
    // Left: Right
    "[": "]",
    "{": "}",
    "<": ">",
    "(": ")",
    // Right: Left
    "]": "[,",
    "}": "{",
    ">": "<",
    ")": "(",
    // Both
    "\"": "\"",
]

// MARK: - Extensions

private extension Collection where Self.Iterator.Element == Character {
    func indexOf(cond: (Character) -> Bool, ignoringConds: [IgnoringCondition]) -> Index? {
        var ignoringCond: IgnoringCondition?
        return firstIndex(where: { (scalar) -> Bool in
            if ignoringCond == nil && cond(scalar) { return true }
            if ignoringCond == nil {
                for cond in ignoringConds where cond.shouldStart(scalar) { ignoringCond = cond }
            }
            if let _ignoringCond = ignoringCond, _ignoringCond.shouldStop(scalar) { ignoringCond = nil }
            return false
        })
    }
}

private extension CharacterSet {
    static let swiftSyntax = CharacterSet(charactersIn: ":,.")
    static let allBoundaries: CharacterSet = {
        let boundaryChars = rules
            .map { $0.value }
            .joined(separator: "")
        return CharacterSet(charactersIn: boundaryChars)
    }()
    static let quotes = CharacterSet(charactersIn: "\"")
    static let colon = CharacterSet(charactersIn: ":")
    static let comma = CharacterSet(charactersIn: ",")
    static let leftBoundaries = CharacterSet(charactersIn: "(<[{")
    static let rightBoundaries = CharacterSet(charactersIn: ")>]}")
    static let allBoundariesAndSpace = CharacterSet(charactersIn: " ")
        .union(.swiftSyntax)
        .union(.allBoundaries)
}
