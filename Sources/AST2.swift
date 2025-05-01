//
//  AST2.swift
//  XCLineFramework
//
//  Created by Robert Chatfield on 1/5/2025.
//

import SwiftDiagnostics
import SwiftOperators
import SwiftParserDiagnostics
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport

import SwiftParser
import SwiftSyntax

extension Buffer {
    public mutating func expandSelectionsWithSwiftSyntax() {
        selections = selections.map(expandedSelection(range:))
    }

    public func expandedSelectionsWithSwiftSyntax() -> Buffer {
        var expandedBuffer = self
        expandedBuffer.expandSelectionsWithSwiftSyntax()
        return expandedBuffer
    }

    private func expandedSelection(range: SourceTextRange) -> SourceTextRange {
        print("🔍 Starting expansion for range: line \(range.start.line):\(range.start.column) to line \(range.end.line):\(range.end.column)")
        
        // Parse the buffer content
        let sourceFile = Parser.parse(source: completeBuffer)
        
        // Convert our position to SwiftSyntax's position
        let startOffset = completeBuffer.utf8.distance(from: completeBuffer.startIndex, to: completeBuffer.lineColumnToIndex(line: range.start.line, column: range.start.column))
        let endOffset = completeBuffer.utf8.distance(from: completeBuffer.startIndex, to: completeBuffer.lineColumnToIndex(line: range.end.line, column: range.end.column))
        
        // Create a visitor to find the best expansion
        let visitor = StringExpander(
            startOffset: startOffset,
            endOffset: endOffset,
            content: completeBuffer
        )
        visitor.walk(sourceFile)
        
        // If we found an expansion, convert it back to our range type
        if let expansion = visitor.bestExpansion {
            // Convert SwiftSyntax's position back to our position
            let startIndex = completeBuffer.utf8.index(completeBuffer.startIndex, offsetBy: expansion.start)
            let endIndex = completeBuffer.utf8.index(completeBuffer.startIndex, offsetBy: expansion.end)
            
            let startLineColumn = completeBuffer.lineColumnAtIndex(startIndex)
            let endLineColumn = completeBuffer.lineColumnAtIndex(endIndex)
            
            let start = SourceTextPosition(line: startLineColumn.line, column: startLineColumn.column)
            let end = SourceTextPosition(line: endLineColumn.line, column: endLineColumn.column)
            
            print("🔍 Expanded to new range: line \(start.line):\(start.column) to line \(end.line):\(end.column)")
            return SourceTextRange(start: start, end: end)
        }
        
        print("🔍 No expansion found, returning original range")
        return range
    }
}

extension String {
    func lineColumnToIndex(line: Int, column: Int) -> String.Index {
        var currentLine = 0
        var currentColumn = 0
        var currentIndex = startIndex
        
        while currentIndex < endIndex {
            if currentLine == line && currentColumn == column {
                return currentIndex
            }
            
            if self[currentIndex] == "\n" {
                currentLine += 1
                currentColumn = 0
            } else {
                currentColumn += 1
            }
            
            currentIndex = index(after: currentIndex)
        }
        
        return endIndex
    }
    
    func lineColumnAtIndex(_ index: String.Index) -> (line: Int, column: Int) {
        var currentLine = 0
        var currentColumn = 0
        var currentIndex = startIndex
        
        while currentIndex < index {
            if self[currentIndex] == "\n" {
                currentLine += 1
                currentColumn = 0
            } else {
                currentColumn += 1
            }
            
            currentIndex = self.index(after: currentIndex)
        }
        
        return (line: currentLine, column: currentColumn)
    }
}

class StringExpander: SyntaxVisitor {
    let startOffset: Int
    let endOffset: Int
    let content: String
    var bestExpansion: (start: Int, end: Int)? = nil
    
    init(startOffset: Int, endOffset: Int, content: String) {
        self.startOffset = startOffset
        self.endOffset = endOffset
        self.content = content
        super.init(viewMode: .sourceAccurate)
    }
    
    override func visit(_ node: StringLiteralExprSyntax) -> SyntaxVisitorContinueKind {
        // Get absolute positions in the source file
        let nodeStart = node.position.utf8Offset
        let nodeEnd = node.endPosition.utf8Offset
        let contentStart = node.openingQuote.endPosition.utf8Offset
        let contentEnd = node.closingQuote.position.utf8Offset
        
        print("🔍 Found string literal:")
        print("🔍   Full range: \(nodeStart)..\(nodeEnd)")
        print("🔍   Content range: \(contentStart)..\(contentEnd)")
        print("🔍   Selection: \(startOffset)..\(endOffset)")
        
        // Only process if our selection overlaps with this string literal
        guard startOffset <= nodeEnd && endOffset >= nodeStart else {
            return .skipChildren
        }
        
        // Get the text content if available
        guard let segment = node.segments.first?.as(StringSegmentSyntax.self) else {
            return .skipChildren
        }
        
        let text = segment.content.text
        
        // Case 1: Selection is inside content - expand to word
        if startOffset >= contentStart && endOffset <= contentEnd {
            let relativeStart = startOffset - contentStart
            let relativeEnd = endOffset - contentStart
            
            // If it's a cursor position or small selection
            if relativeStart == relativeEnd || (relativeEnd - relativeStart <= 2) {
                var wordStart = relativeStart
                var wordEnd = relativeStart
                
                // Search backwards for word start
                while wordStart > 0 && !text[text.index(text.startIndex, offsetBy: wordStart - 1)].isWhitespace {
                    wordStart -= 1
                }
                
                // Search forwards for word end
                while wordEnd < text.count && !text[text.index(text.startIndex, offsetBy: wordEnd)].isWhitespace {
                    wordEnd += 1
                }
                
                // If we found a word and it's different from current selection
                if wordStart < wordEnd && (wordStart != relativeStart || wordEnd != relativeEnd) {
                    bestExpansion = (contentStart + wordStart, contentStart + wordEnd)
                    return .skipChildren
                }
            }
            
            // Case 2: Word is selected - expand to content
            bestExpansion = (contentStart, contentEnd)
            return .skipChildren
        }
        
        // Case 3: Content is selected - expand to include quotes
        if startOffset == contentStart && endOffset == contentEnd {
            // Expand to include quotes with cursor outside
            let startIndex = content.utf8.index(content.startIndex, offsetBy: startOffset)
            let startLineColumn = content.lineColumnAtIndex(startIndex)
            bestExpansion = (startLineColumn.column - 1, startLineColumn.column + node.totalLength.utf8Length)
            return .skipChildren
        }
        
        // Case 4: Quotes are selected - no further expansion needed
        if startOffset == contentStart - 1 && endOffset == contentEnd + 1 {
            return .skipChildren
        }
        
        return .skipChildren
    }
}

