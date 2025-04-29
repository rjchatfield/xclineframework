import Foundation

extension Collection where Element == Character {
    func safeIndex(offset: Int) -> Index? {
        return index(startIndex, offsetBy: offset, limitedBy: endIndex)
    }

    func firstIndex(in set: CharacterSet) -> Index? {
        firstIndex(where: set.contains)
    }
}

extension StringProtocol where SubSequence == Substring {
    func safeSubstring(to: Int) -> Substring {
        guard let end = safeIndex(offset: to) else { return "" }
        return self[startIndex..<end]
    }
    
    func safeSubstring(from: Int, to: Int) -> Substring {
        guard from >= 0, from <= to,
              let start = safeIndex(offset: from),
              let end = safeIndex(offset: to)
        else { return "" }
        return self[start..<end]
    }
    
    func safeSubstring(from: Int) -> Substring {
        guard from >= 0, let start = safeIndex(offset: from) else { return "" }
        return self[start..<endIndex]
    }

    func partition(start: Int, end: Int) -> (Substring, Substring, Substring) {
        return (
            safeSubstring(to: start),
            safeSubstring(from: start, to: end),
            safeSubstring(from: end)
        )
    }
    
    func partition(at: Int) -> (Substring, Substring) {
        return (
            safeSubstring(to: at),
            safeSubstring(from: at)
        )
    }
}

extension Substring {
    func contains(anyOf characterSet: CharacterSet) -> Bool {
        return unicodeScalars.contains { characterSet.contains($0) }
    }
    
    func doesNotContain(anyOf characterSet: CharacterSet) -> Bool {
        return !contains(anyOf: characterSet)
    }
}

extension CharacterSet {
    func contains(_ member: Character) -> Bool {
        guard let unicodeScalar = member.unicodeScalars.first else { return false }
        return contains(unicodeScalar)
    }
    
    func doesNotContain(_ member: Character) -> Bool {
        return !contains(member)
    }
}

extension Character {
    func isContained(in characterSet: CharacterSet) -> Bool {
        return characterSet.contains(self)
    }
    
    func isNotContained(in characterSet: CharacterSet) -> Bool {
        return !isContained(in: characterSet)
    }
}
