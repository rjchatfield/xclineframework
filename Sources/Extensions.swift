import Foundation

extension StringProtocol where SubSequence == Substring {
    
    func index(_ i: Int) -> Index? {
        return index(startIndex, offsetBy: i, limitedBy: endIndex)
    }
    
    func substring(to: Int) -> Substring {
        guard let end = index(to) else { return "" }
        return self[startIndex..<end]
    }
    
    func substring(from: Int, to: Int) -> Substring {
        guard from >= 0, from <= to, let start = index(from), let end = index(to) else { return "" }
        return self[start..<end]
    }
    
    func substring(from: Int) -> Substring {
        guard from >= 0, let start = index(from) else { return "" }
        return self[start..<endIndex]
    }
    
    func partition(start: Int, end: Int) -> (Substring, Substring, Substring) {
        return (
            substring(to: start),
            substring(from: start, to: end),
            substring(from: end)
        )
    }
    
    func partition(at: Int) -> (Substring, Substring) {
        return (
            substring(to: at),
            substring(from: at)
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
