extension StringProtocol where SubSequence == Substring {
    func partition(start: Int, end: Int) -> (Substring, Substring, Substring) {
        return (
            safeSubstring(to: start),
            safeSubstring(from: start, to: end),
            safeSubstring(from: end)
        )
    }

    private func safeSubstring(to: Int) -> Substring {
        guard let end = safeIndex(offset: to) else { return "" }
        return self[startIndex..<end]
    }
    
    private func safeSubstring(from: Int, to: Int) -> Substring {
        guard from >= 0, from <= to,
              let start = safeIndex(offset: from),
              let end = safeIndex(offset: to)
        else { return "" }
        return self[start..<end]
    }
    
    private func safeSubstring(from: Int) -> Substring {
        guard from >= 0, let start = safeIndex(offset: from) else { return "" }
        return self[start..<endIndex]
    }

    private func safeIndex(offset: Int) -> Index? {
        return index(startIndex, offsetBy: offset, limitedBy: endIndex)
    }
}
