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
