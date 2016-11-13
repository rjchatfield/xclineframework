import Foundation

extension Line {
    
    public func expandRegion() -> Line {
        var result = self
        result.untrimSelection()
        result = result._expandRegion()
        result.trimSelection()
        return result
    }
    
}

// MARK: - Helper methods

private extension Line {
    var leftBoundary: UnicodeScalar? {
        guard start > 0 else { return nil }
        guard let index = chars.index(chars.startIndex, offsetBy: start - 1, limitedBy: chars.endIndex) else { return nil }
        return chars[index]
    }
    var rightBoundary: UnicodeScalar? {
        guard end < chars.count else { return nil }
        guard let index = chars.index(chars.startIndex, offsetBy: end, limitedBy: chars.endIndex) else { return nil }
        return chars[index]
    }
    func prevBoundary(includeQuotes: Bool, includeComma: Bool, includeColon: Bool) -> Int {
        let reversedStartChars = startChars.reversed()
        var boundaries = CharacterSet.leftBoundaries
        if includeQuotes { boundaries = boundaries.union(.quotes) }
        if includeComma { boundaries = boundaries.union(.comma) }
        if includeColon { boundaries = boundaries.union(.colon) }
        if let i = reversedStartChars.indexOf(cond: boundaries.contains, ignoringConds: ignoringCondsFlipped) {
            return start - reversedStartChars.distance(from: reversedStartChars.startIndex, to: i)
        }
        return 0
    }
    func nextBoundary(includeQuotes: Bool, includeComma: Bool, includeColon: Bool) -> Int {
        var boundaries = CharacterSet.rightBoundaries
        if includeQuotes { boundaries = boundaries.union(.quotes) }
        if includeComma { boundaries = boundaries.union(.comma) }
        if includeColon { boundaries = boundaries.union(.colon) }
        if let i = endChars.indexOf(cond: boundaries.contains, ignoringConds: ignoringConds) {
            return end + endChars.distance(from: endChars.startIndex, to: i)
        }
        return string.unicodeScalars.count
    }
    mutating func untrimSelection() {
        let reversedStartChars = startChars.reversed()
        if let startTrim = reversedStartChars.index(where: CharacterSet.whitespacesAndNewlines.doesNotContain) {
            let dist = reversedStartChars.distance(from: reversedStartChars.startIndex, to: startTrim)
            if dist <= start {
                start -= dist
            }
        }
        if let endTrim = endChars.index(where: CharacterSet.whitespacesAndNewlines.doesNotContain) {
            let dist = endChars.distance(from: endChars.startIndex, to: endTrim)
            if dist < chars.count - end {
                end += dist
            }
        }
    }
    mutating func trimSelection() {
        if let startTrim = selectedChars.index(where: CharacterSet.whitespacesAndNewlines.doesNotContain) {
            let dist = selectedChars.distance(from: selectedChars.startIndex, to: startTrim)
            let newStart = start + dist
            if newStart <= end {
                start = newStart
            }
        }
        let reversedSelectedChars = selectedChars.reversed()
        if let endTrim = reversedSelectedChars.index(where: CharacterSet.whitespacesAndNewlines.doesNotContain) {
            let dist = reversedSelectedChars.distance(from: reversedSelectedChars.startIndex, to: endTrim)
            let newEnd = end - dist
            if newEnd >= start {
                end = newEnd
            }
        }
    }
    var hasNoTextSelected: Bool {
        return start == end
    }
    var couldBeInAWord: Bool {
        guard
            selectedChars.doesNotContain(anyOf: .allBoundariesAndSpace),
            let beforeBoundary = startChars.last,
            let afterBoundary = endChars.first
            else {
                return false
        }
        return beforeBoundary.isNotContained(in: .allBoundariesAndSpace)
            || afterBoundary.isNotContained(in: .allBoundariesAndSpace)
    }
    var coundBeInAParam: Bool {
        if rightBoundary == ":" { return false }
        if startChars.doesNotContain(anyOf: .colon) { return false }
        if leftBoundary?.isContained(in: CharacterSet.colon.union(.comma)) == true &&
            rightBoundary?.isContained(in: CharacterSet.rightBoundaries.union(.comma)) == true { return false }
        if leftBoundary?.isContained(in: .leftBoundaries) == true { return false }
        return true
    }
    var coundBeInAPair: Bool {
        if leftBoundary?.isContained(in: CharacterSet.leftBoundaries.union(.comma)) == true &&
            rightBoundary?.isContained(in: CharacterSet.rightBoundaries.union(.comma)) == true { return false }
        return true
    }
    var couldBeInAString: Bool {
        if selectedChars.contains(anyOf: .quotes) { return false }
        if startChars.contains(anyOf: .quotes) && endChars.contains(anyOf: .quotes) { return true }
        return false
    }
    func compareBoundaries(includeQuotes: Bool, includeComma: Bool, includeColon: Bool) -> ComparisonResult {
        switch (leftBoundary, rightBoundary) {
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
    static let rules: [UnicodeScalar: String] = [
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
    static func boundaries(major: CharacterSet, includeQuotes: Bool, includeComma: Bool, includeColon: Bool) -> (CharacterSet, CharacterSet) {
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
    func leftBoundaryScore(_ x: UnicodeScalar, includeQuotes: Bool, includeComma: Bool, includeColon: Bool) -> Int {
        let (majorBoundaries, minorBoundaries) = Line.boundaries(major: .leftBoundaries, includeQuotes: includeQuotes, includeComma: includeComma, includeColon: includeColon)
        if majorBoundaries.contains(x) { return 2 }
        if minorBoundaries.contains(x) { return 1 }
        return 0
    }
    func rightBoundaryScore(_ x: UnicodeScalar, includeQuotes: Bool, includeComma: Bool, includeColon: Bool) -> Int {
        let (majorBoundaries, minorBoundaries) = Line.boundaries(major: .rightBoundaries, includeQuotes: includeQuotes, includeComma: includeComma, includeColon: includeColon)
        if majorBoundaries.contains(x) { return 2 }
        if minorBoundaries.contains(x) { return 1 }
        return 0
    }
    var boundariesExactlyMatch: Bool {
        guard
            let lhs = leftBoundary,
            let rhs = rightBoundary,
            let matches = Line.rules[lhs]
            else { return false }
        return CharacterSet(charactersIn: matches).contains(rhs)
    }
    func expandWord() -> Line {
        var result = self
        // Start
        let startIndex = chars.index(chars.startIndex, offsetBy: start)
        let startChars = chars[chars.startIndex..<startIndex]
        if let newStart = startChars.reversed().index(where: CharacterSet.allBoundariesAndSpace.contains) {
            result.start = chars.distance(from: chars.startIndex, to: newStart.base)
        } else {
            result.start = 0
        }
        // End
        let endIndex = chars.index(chars.startIndex, offsetBy: end)
        let endScalars = chars[endIndex..<chars.endIndex]
        if let newEnd = endScalars.index(where: CharacterSet.allBoundariesAndSpace.contains) {
            result.end += chars.distance(from: chars.startIndex, to: newEnd)
        } else {
            result.end = string.unicodeScalars.count
        }
        return result
    }
    var hasNoStartBoundaryToParse: Bool {
        return start <= 0
    }
    var hasNoEndBoundaryToParse: Bool {
        return end >= string.unicodeScalars.count
    }
    func expandedToBoundary(includeQuotes: Bool, includeComma: Bool, includeColon: Bool) -> (Line, finished: Bool) {
        var line = self
        line.start = line.prevBoundary(includeQuotes: includeQuotes, includeComma: includeComma, includeColon: includeColon)
        line.end = line.nextBoundary(includeQuotes: includeQuotes, includeComma: includeComma, includeColon: includeColon)
        if line.hasNoStartBoundaryToParse && line.hasNoEndBoundaryToParse { return (line, true) }
        if line.boundariesExactlyMatch { return (line, true) }
        switch line.compareBoundaries(includeQuotes: includeQuotes, includeComma: includeComma, includeColon: includeColon) {
        case .orderedSame: return (line, true)
        case .orderedAscending: if line.start > 0 { line.start -= 1 } else { return (line, true) }
        case .orderedDescending: if line.end < line.chars.count { line.end += 1 } else { return (line, true) }
        }
        return (line, false)
    }
    func _expandRegion() -> Line {
        if hasNoTextSelected && couldBeInAWord {
            return expandWord()
        }
        if couldBeInAWord {
            return expandWord()
        }
        if boundariesExactlyMatch {
            var result = self
            result.start -= 1
            result.end += 1
            return result
        }
        var remaining = self
        var willExpandToQuotes = true
        var willExpandToComma = true
        var willExpandToColon = true
        repeat {
            if willExpandToQuotes && !couldBeInAString { willExpandToQuotes = false }
            if willExpandToComma && !coundBeInAPair { willExpandToComma = false }
            if willExpandToColon && !coundBeInAParam { willExpandToColon = false }
            let (expandedLine, finished) = remaining.expandedToBoundary(includeQuotes: willExpandToQuotes, includeComma: willExpandToComma, includeColon: willExpandToColon)
            if finished { return expandedLine }
            remaining = expandedLine
        } while !remaining.hasNoStartBoundaryToParse || !remaining.hasNoEndBoundaryToParse
        return remaining
    }
    
}

private typealias Condition = (UnicodeScalar) -> Bool
private typealias IgnoringCondition = (shouldStart: Condition, shouldStop: Condition)

private let ignoringConds: [IgnoringCondition] = [
    ({ $0 == "[" }, { $0 == "]" }) as IgnoringCondition,
    ({ $0 == "(" }, { $0 == ")" }) as IgnoringCondition,
    ({ $0 == "{" }, { $0 == "}" }) as IgnoringCondition,
    ({ $0 == "<" }, { $0 == ">" }) as IgnoringCondition,
]

private let ignoringCondsFlipped: [IgnoringCondition] = ignoringConds.map { cond in (cond.1, cond.0) }

// MARK: - Extensions

private extension Collection where Self.Iterator.Element == UnicodeScalar {
    
    func indexOf(cond: Condition, ignoringConds: [IgnoringCondition]) -> Index? {
        var ignoringCond: IgnoringCondition?
        return index(where: { (scalar) -> Bool in
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
    static let allBoundaries = CharacterSet(charactersIn: Line.rules
        .map { $0.value }
        .joined(separator: ""))
    static let quotes = CharacterSet(charactersIn: "\"")
    static let colon = CharacterSet(charactersIn: ":")
    static let comma = CharacterSet(charactersIn: ",")
    static let colonAndCommar = CharacterSet.colon.union(.comma)
    static let leftBoundaries = CharacterSet(charactersIn: "(<[{")
    static let leftBoundariesWithQuotes = CharacterSet.leftBoundaries
        .union(.quotes)
    static let rightBoundaries = CharacterSet(charactersIn: ")>]}")
    static let rightBoundariesWithQuotes = CharacterSet.rightBoundaries
        .union(.quotes)
    static let allBoundariesAndSpace = CharacterSet(charactersIn: " ")
        .union(.swiftSyntax)
        .union(.allBoundaries)
    
    func doesNotContain(_ member: UnicodeScalar) -> Bool {
        return !contains(member)
    }
    
}
