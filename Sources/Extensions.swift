import Foundation

extension String {
    
    func index(_ i: Int) -> Index? {
        return index(startIndex, offsetBy: i, limitedBy: endIndex)
    }
    
    func substring(to: Int) -> String {
        guard let end = index(to) else { return "" }
        return self[startIndex..<end]
    }
    
    func substring(from: Int, to: Int) -> String {
        guard from >= 0, from <= to, let start = index(from), let end = index(to) else { return "" }
        return self[start..<end]
    }
    
    func substring(from: Int) -> String {
        guard from >= 0, let start = index(from) else { return "" }
        return self[start..<endIndex]
    }
    
    func partition(start: Int, end: Int) -> (String, String, String) {
        return (
            substring(to: start),
            substring(from: start, to: end),
            substring(from: end)
        )
    }
    
    func partition(at: Int) -> (String, String) {
        return (
            substring(to: at),
            substring(from: at)
        )
    }
    
    func contains(anyOf characterSet: CharacterSet) -> Bool {
        return unicodeScalars.contains(anyOf: characterSet)
    }
    
    func doesNotContain(anyOf characterSet: CharacterSet) -> Bool {
        return !contains(anyOf: characterSet)
    }
    
}

extension String.UnicodeScalarView {
    
    func contains(anyOf characterSet: CharacterSet) -> Bool {
        return contains { characterSet.contains($0) }
    }
    
    func doesNotContain(anyOf characterSet: CharacterSet) -> Bool {
        return !contains(anyOf: characterSet)
    }
    
}

extension UnicodeScalar {
    
    func isContained(in characterSet: CharacterSet) -> Bool {
        return characterSet.contains(self)
    }
    
    func isNotContained(in characterSet: CharacterSet) -> Bool {
        return !isContained(in: characterSet)
    }
    
}

extension CharacterSet {
    
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

extension Collection where Self.Iterator.Element == UnicodeScalar {
    
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
