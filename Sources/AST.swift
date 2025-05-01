//
//  AST.swift
//  XCLineFramework
//
//  Created by Robert Chatfield on 1/5/2025.
//

import SourceKittenFramework

extension Buffer {
    public mutating func expandSelections() {
        selections = expandedSelections()
    }

    public func expandedSelections() -> [SourceTextRange] {
        selections.map(expandedSelection(range:))
    }

    private func expandedSelection(range: SourceTextRange) -> SourceTextRange {
        print("🔍 Starting expansion for range: line \(range.start.line):\(range.start.column) to line \(range.end.line):\(range.end.column)")
        
        // Get the AST from SourceKitten
        let file = File(contents: completeBuffer)
        guard let structure = try? Structure(file: file) else {
            print("🔍 Failed to get structure from SourceKitten")
            return range // Return original range if we can't get structure
        }
        print("🔍 Successfully got AST structure")

        // Convert our SourceTextRange to byte range for SourceKitten
        let startOffset = byteOffset(for: range.start)
        let endOffset = byteOffset(for: range.end)
        let currentLength = endOffset - startOffset
        print("🔍 Converted to byte offsets - start: \(startOffset), end: \(endOffset), length: \(currentLength)")

        // Find all syntax nodes that contain our selection
        var containingNodes: [[String: SourceKitRepresentable]] = []

        func findNodes(in dict: [String: SourceKitRepresentable]) {
            if let offset = dict["key.offset"] as? Int64,
               let length = dict["key.length"] as? Int64 {
                let nodeEnd = Int(offset) + Int(length)
                if Int(offset) <= startOffset && nodeEnd >= endOffset {
                    containingNodes.append(dict)
                }
            }

            // Recursively check substructure
            if let substructure = dict["key.substructure"] as? [[String: SourceKitRepresentable]] {
                for item in substructure {
                    findNodes(in: item)
                }
            }
        }

        findNodes(in: structure.dictionary)
        print("🔍 Found \(containingNodes.count) containing nodes")

        // Group nodes by their offset
        var nodesByOffset: [Int64: [String: SourceKitRepresentable]] = [:]
        for node in containingNodes {
            let offset = node["key.offset"] as? Int64 ?? 0
            if nodesByOffset[offset] == nil || 
               (nodesByOffset[offset]?["key.length"] as? Int64 ?? 0) > (node["key.length"] as? Int64 ?? 0) {
                nodesByOffset[offset] = node
            }
        }
        
        // Sort nodes by length
        let sortedNodes = nodesByOffset.values.sorted { node1, node2 in
            let length1 = node1["key.length"] as? Int64 ?? 0
            let length2 = node2["key.length"] as? Int64 ?? 0
            return length1 < length2
        }
        
        print("🔍 Found nodes:")
        for node in sortedNodes {
            let length = node["key.length"] as? Int64 ?? 0
            let offset = node["key.offset"] as? Int64 ?? 0
            let kind = node["key.kind"] as? String ?? "unknown"
            let text = String(completeBuffer.utf8.dropFirst(Int(offset)).prefix(Int(length)))
            print("🔍   Kind: \(kind)")
            print("🔍   Length: \(length)")
            print("🔍   Text: '\(text)'")
            print("🔍   ---")
        }

        guard let nextNode = sortedNodes.first(where: { node in
            guard let length = node["key.length"] as? Int64 else { return false }
            let nodeOffset = node["key.offset"] as? Int64 ?? Int64(startOffset)
            let nodeText = String(completeBuffer.utf8.dropFirst(Int(nodeOffset)).prefix(Int(length)))!
            
            let nodeStart = Int(nodeOffset)
            let nodeEnd = nodeStart + Int(length)
            let selectionStart = startOffset - nodeStart
            let selectionEnd = endOffset - nodeStart
            
            print("🔍 Checking node:")
            print("🔍   Text: '\(nodeText)'")
            print("🔍   Current length: \(currentLength)")
            print("🔍   Node length: \(length)")
            print("🔍   Selection: \(selectionStart)-\(selectionEnd)")
            
            // Helper function to find the smallest containing substring
            func findSmallestContainer() -> (start: Int, end: Int, type: String)? {
                // Try to find quoted strings and words within them
                if let quoteStart = nodeText.firstIndex(of: "\""),
                   let quoteEnd = nodeText[nodeText.index(after: quoteStart)...].firstIndex(of: "\"") {
                    let start = nodeText.distance(from: nodeText.startIndex, to: quoteStart)
                    let end = nodeText.distance(from: nodeText.startIndex, to: quoteEnd) + 1
                    let contentStart = start + 1
                    let contentEnd = end - 1
                    
                    // If cursor is inside the quoted content
                    if selectionStart >= contentStart && selectionStart < contentEnd {
                        // If we don't have a selection yet, try to select a word
                        if currentLength == 0 {
                            let content = String(nodeText[nodeText.index(nodeText.startIndex, offsetBy: contentStart)..<nodeText.index(nodeText.startIndex, offsetBy: contentEnd)])
                            let words = content.split(separator: " ")
                            for word in words {
                                if let range = content.range(of: word) {
                                    let wordStart = contentStart + content.distance(from: content.startIndex, to: range.lowerBound)
                                    let wordEnd = wordStart + word.count
                                    if selectionStart >= wordStart && selectionStart < wordEnd {
                                        return (wordStart, wordEnd, "word")
                                    }
                                }
                            }
                        }
                        
                        // If we have a word selected, expand to quoted content
                        if currentLength > 0 && selectionStart > contentStart && selectionEnd < contentEnd {
                            return (contentStart, contentEnd, "quoted-content")
                        }
                        
                        // If we have the quoted content selected, expand to include quotes
                        if selectionStart == contentStart && selectionEnd == contentEnd {
                            return (start, end, "quoted-full")
                        }
                    }
                }
                return nil
            }
            
            // Find the smallest container
            if let container = findSmallestContainer() {
                let containerLength = container.end - container.start
                
                // If we don't have anything selected yet
                if currentLength == 0 {
                    print("🔍   Should select \(container.type)")
                    return true
                }
                
                // If we have a word selected
                if container.type == "word" && selectionStart == container.start && selectionEnd == container.end {
                    // Look for quotes around our selection
                    let beforeText = nodeText[..<nodeText.index(nodeText.startIndex, offsetBy: container.start)]
                    let afterText = nodeText[nodeText.index(nodeText.startIndex, offsetBy: container.end)...]
                    if beforeText.hasSuffix("\"") && afterText.prefix(1) == "\"" {
                        print("🔍   Should select quoted content")
                        return true
                    }
                }
                
                // If we have quoted content selected
                if container.type == "quoted-content" && selectionStart == container.start && selectionEnd == container.end {
                    print("🔍   Should select quoted full")
                    return true
                }
                
                // If we have a full quoted string selected
                if container.type == "quoted-full" && selectionStart == container.start && selectionEnd == container.end {
                    print("🔍   Should not expand further")
                    return false
                }
                
                // If we have part of something, select all of it
                if currentLength < containerLength {
                    print("🔍   Should select full \(container.type)")
                    return true
                }
            }
            
            print("🔍   Should not select this node")
            return false
        }) else {
            print("🔍 No larger node found, returning original range")
            return range // Return original range if no larger node found
        }
        print("🔍 Found next larger node with kind: \(nextNode["key.kind"] as? String ?? "unknown")")

        // Convert the node's range back to SourceTextRange
        let nodeOffset = nextNode["key.offset"] as? Int64 ?? Int64(startOffset)
        let nodeLength = nextNode["key.length"] as? Int64 ?? 0
        let nodeText = String(completeBuffer.utf8.dropFirst(Int(nodeOffset)).prefix(Int(nodeLength)))!

        // Calculate offsets to trim whitespace
        let leadingWS = nodeText.prefix(while: { $0.isWhitespace }).utf8.count
        let trailingWS = String(nodeText.reversed().prefix(while: { $0.isWhitespace })).utf8.count

        let trimmedStart = sourcePosition(forByteOffset: Int(nodeOffset) + leadingWS)
        let trimmedEnd = sourcePosition(forByteOffset: Int(nodeOffset + nodeLength) - trailingWS)
        
        print("🔍 Expanded to new range: line \(trimmedStart.line):\(trimmedStart.column) to line \(trimmedEnd.line):\(trimmedEnd.column)")
        return SourceTextRange(start: trimmedStart, end: trimmedEnd)
    }

    // Helper to convert SourceTextPosition to byte offset
    private func byteOffset(for position: SourceTextPosition) -> Int {
        // This is a simplified implementation - you'll need to properly handle
        // UTF-8 encoding and actual line endings in your buffer
        let lines = completeBuffer.split(separator: "\n")
        var offset = 0

        // Add up lengths of previous lines plus newline characters
        for i in 0..<position.line {
            if i < lines.count {
                offset += lines[i].utf8.count + 1 // +1 for newline
            }
        }

        // Add column offset for the current line
        if position.line < lines.count {
            let currentLine = lines[position.line]
            let columnBytes = currentLine.prefix(position.column).utf8.count
            offset += columnBytes
        }

        return offset
    }

    // Helper to convert byte offset to SourceTextPosition
    private func sourcePosition(forByteOffset offset: Int) -> SourceTextPosition {
        // This is a simplified implementation - you'll need to properly handle
        // UTF-8 encoding and actual line endings in your buffer
        let lines = completeBuffer.split(separator: "\n")
        var currentOffset = 0
        var currentLine = 0

        // Find the line containing this offset
        while currentLine < lines.count {
            let lineLength = lines[currentLine].utf8.count + 1 // +1 for newline
            if currentOffset + lineLength > offset {
                break
            }
            currentOffset += lineLength
            currentLine += 1
        }

        // Calculate column within the line
        let column: Int
        if currentLine < lines.count {
            let utf8Line = lines[currentLine].utf8
            if let columnIndex = utf8Line.index(utf8Line.startIndex, offsetBy: offset - currentOffset, limitedBy: utf8Line.endIndex) {
                column = Array(lines[currentLine].utf8[..<columnIndex]).count
            } else {
                column = 0
            }
        } else {
            column = 0
        }

        return SourceTextPosition(line: currentLine, column: column)
    }
}

public struct Buffer: Equatable {
    public let completeBuffer: String
    public var selections: [SourceTextRange]

    public init(completeBuffer: String, selections: [SourceTextRange]) {
        self.completeBuffer = completeBuffer
        self.selections = selections
    }

    private typealias Raw = (before: Substring, selected: Substring, after: Substring)

    @_spi(Testing)
    public init(testString: String) {
        let raw = makeRaw(testString)!
        self.init(
            completeBuffer: String(raw.before + raw.selected + raw.after),
            selections: [
                SourceTextRange(
                    start: SourceTextPosition(line: 0, column: raw.before.count),
                    end: SourceTextPosition(line: 0, column: raw.before.count + raw.selected.count)
                )
            ]
        )
    }

    @_spi(Testing)
    public var rawDescription: String {
        let start = selections[0].start.column
        let end = selections[0].end.column
        let raw: Raw = completeBuffer.partition(start: start, end: end)
        return "\(raw.before)|\(raw.selected)|\(raw.after)"
    }
}

public struct SourceTextRange: Equatable {
    public let start: SourceTextPosition
    public let end: SourceTextPosition

    public init(start: SourceTextPosition, end: SourceTextPosition) {
        self.start = start
        self.end = end
    }
}

public struct SourceTextPosition: Equatable {
    public var line: Int
    public var column: Int

    public init(line: Int, column: Int) {
        self.line = line
        self.column = column
    }
}
