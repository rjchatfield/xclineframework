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
        // Get the AST from SourceKitten
        let file = File(contents: completeBuffer)
        guard let structure = try? Structure(file: file) else {
            return range // Return original range if we can't get structure
        }

        // Convert our SourceTextRange to byte range for SourceKitten
        let startOffset = byteOffset(for: range.start)
        let endOffset = byteOffset(for: range.end)
        let currentLength = endOffset - startOffset

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

        // Sort nodes by length and find the next largest one
        let sortedNodes = containingNodes.sorted { node1, node2 in
            let length1 = node1["key.length"] as? Int64 ?? 0
            let length2 = node2["key.length"] as? Int64 ?? 0
            return length1 < length2
        }

        guard let nextNode = sortedNodes.first(where: { node in
            guard let length = node["key.length"] as? Int64 else { return false }
            return Int(length) > currentLength
        }) else {
            return range // Return original range if no larger node found
        }

        // Convert the node's range back to SourceTextRange
        let nodeOffset = nextNode["key.offset"] as? Int64 ?? Int64(startOffset)
        let nodeLength = nextNode["key.length"] as? Int64 ?? 0
        let nodeStart = sourcePosition(forByteOffset: Int(nodeOffset))
        let nodeEnd = sourcePosition(forByteOffset: Int(nodeOffset + nodeLength))
        return SourceTextRange(start: nodeStart, end: nodeEnd)
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

public struct Buffer {
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

public struct SourceTextRange {
    public let start: SourceTextPosition
    public let end: SourceTextPosition

    public init(start: SourceTextPosition, end: SourceTextPosition) {
        self.start = start
        self.end = end
    }
}

public struct SourceTextPosition {
    public var line: Int
    public var column: Int

    public init(line: Int, column: Int) {
        self.line = line
        self.column = column
    }
}
