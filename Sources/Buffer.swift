//
//  Buffer.swift
//  XCLineFramework
//
//  Created by Robert Chatfield on 1/5/2025.
//

import Foundation

public struct Buffer: Equatable {
    public let completeBuffer: String
    public var selections: [SourceTextRange]
    
    private let tokens: [Token]
    private var context: ContextStack

    public init(completeBuffer: String, selections: [SourceTextRange]) {
        self.completeBuffer = completeBuffer
        self.selections = selections
        var tokenizer = Tokenizer(text: completeBuffer)
        self.tokens = tokenizer.tokenize()
        self.context = ContextStack()
    }

    public static func == (lhs: Buffer, rhs: Buffer) -> Bool {
        return lhs.completeBuffer == rhs.completeBuffer && lhs.selections == rhs.selections
    }

    private typealias Raw = (before: Substring, selected: Substring, after: Substring)

    @_spi(Testing)
    public init(testString: String) {
        let raw: (before: Substring, selected: Substring, after: Substring) = makeRaw(testString)!
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
    
    public mutating func expandedSelection() -> Buffer {
        guard let selection = selections.first else { return self }
        
        let startIndex = completeBuffer.index(completeBuffer.startIndex, offsetBy: selection.start.column)
        let endIndex = completeBuffer.index(completeBuffer.startIndex, offsetBy: selection.end.column)
        let selectionRange = startIndex..<endIndex
        
        let expandedRange = expand(selection: selectionRange)
        
        let newStart = completeBuffer.distance(from: completeBuffer.startIndex, to: expandedRange.lowerBound)
        let newEnd = completeBuffer.distance(from: completeBuffer.startIndex, to: expandedRange.upperBound)
        
        return Buffer(
            completeBuffer: completeBuffer,
            selections: [
                SourceTextRange(
                    start: SourceTextPosition(line: 0, column: newStart),
                    end: SourceTextPosition(line: 0, column: newEnd)
                )
            ]
        )
    }
    
    // MARK: - Private Expansion Logic
    
    private func expand(selection: Range<String.Index>) -> Range<String.Index> {
        // 1) Cursor expands to nearest word
        if selection.lowerBound == selection.upperBound {
            return expandInRootContext(selection)
        }

        // 2) If inside a quoted string, do string expansion first
        let quoteTokens = tokens.filter { $0.kind == .quote }
        if let startQuote = quoteTokens.first, let endQuote = quoteTokens.last {
            let fullRange = startQuote.range.lowerBound..<endQuote.range.upperBound
            if selection.lowerBound >= fullRange.lowerBound && selection.upperBound <= fullRange.upperBound {
                return expandInStringContext(selection)
            }
        }

        // 3) Find tokens that overlap with the selection
        let overlappingTokens = tokens.filter { token in
            token.range.overlaps(selection)
        }
        
        guard !overlappingTokens.isEmpty else {
            // If no tokens overlap, find the nearest token
            return findNearestToken(for: selection)
        }
        
        // 4) Delegate to context-specific expansion
        let context = determineContext(for: overlappingTokens)
        return expandInContext(context, selection: selection)
    }
    
    private func findNearestToken(for selection: Range<String.Index>) -> Range<String.Index> {
        // Find the token that starts closest to the selection
        let startToken = tokens.min { token1, token2 in
            let dist1 = completeBuffer.distance(from: token1.range.lowerBound, to: selection.lowerBound)
            let dist2 = completeBuffer.distance(from: token2.range.lowerBound, to: selection.lowerBound)
            return abs(dist1) < abs(dist2)
        }
        
        return startToken?.range ?? selection
    }
    
    private func determineContext(for tokens: [Token]) -> TokenContext {
        // Determine the most specific context from the tokens
        if tokens.contains(where: { $0.kind == .quote }) {
            return .string
        }
        
        // Check for function context
        if let bracketIndex = tokens.firstIndex(where: { $0.kind == .bracket && $0.value == "(" }) {
            if bracketIndex > 0 && tokens[bracketIndex - 1].kind == .word {
                return .function
            }
        }
        
        // Check for array context
        if tokens.contains(where: { $0.kind == .bracket && $0.value == "[" }) {
            return .array
        }
        
        // Check for closure context
        if tokens.contains(where: { $0.kind == .bracket && $0.value == "{" }) {
            return .closure
        }
        
        // Check for generic context
        if tokens.contains(where: { $0.kind == .bracket && $0.value == "<" }) {
            return .generic
        }
        
        return .root
    }
    
    private func expandInContext(_ context: TokenContext, selection: Range<String.Index>) -> Range<String.Index> {
        switch context {
        case .string:
            return expandInStringContext(selection)
        case .function:
            return expandInFunctionContext(selection)
        case .array:
            return expandInArrayContext(selection)
        case .closure:
            return expandInClosureContext(selection)
        case .generic:
            return expandInGenericContext(selection)
        default:
            return expandInRootContext(selection)
        }
    }
    
    private func expandInStringContext(_ selection: Range<String.Index>) -> Range<String.Index> {
        // Multi-stage string expansion: word/partial -> full content -> include quotes
        let quotes = tokens.filter { $0.kind == .quote }
        guard let startQuote = quotes.first, let endQuote = quotes.last else {
            return selection
        }
        let contentStart = startQuote.range.upperBound
        let contentEnd = endQuote.range.lowerBound
        let contentRange = contentStart..<contentEnd
        let fullRange = startQuote.range.lowerBound..<endQuote.range.upperBound
        
        // stage 1: inside content -> expand to content
        if selection.lowerBound >= contentStart && selection.upperBound <= contentEnd {
            // if content fully selected -> include quotes
            if selection == contentRange {
                return fullRange
            }
            return contentRange
        }
        // stage 2: include quotes
        return fullRange
    }
    
    private func expandInFunctionContext(_ selection: Range<String.Index>) -> Range<String.Index> {
        // Find the function name and parameters
        let relevantTokens = tokens.filter { token in
            token.range.overlaps(selection) || token.kind == .bracket
        }
        
        guard let startToken = relevantTokens.first,
              let endToken = relevantTokens.last else {
            return selection
        }
        
        return startToken.range.lowerBound..<endToken.range.upperBound
    }
    
    private func expandInArrayContext(_ selection: Range<String.Index>) -> Range<String.Index> {
        // Find the array brackets
        let brackets = tokens.filter { $0.kind == .bracket && ($0.value == "[" || $0.value == "]") }
        guard let startBracket = brackets.first(where: { $0.range.lowerBound <= selection.lowerBound }),
              let endBracket = brackets.last(where: { $0.range.upperBound >= selection.upperBound }) else {
            return selection
        }
        
        return startBracket.range.lowerBound..<endBracket.range.upperBound
    }
    
    private func expandInClosureContext(_ selection: Range<String.Index>) -> Range<String.Index> {
        // Find the closure braces
        let braces = tokens.filter { $0.kind == .bracket && ($0.value == "{" || $0.value == "}") }
        guard let startBrace = braces.first(where: { $0.range.lowerBound <= selection.lowerBound }),
              let endBrace = braces.last(where: { $0.range.upperBound >= selection.upperBound }) else {
            return selection
        }
        
        return startBrace.range.lowerBound..<endBrace.range.upperBound
    }
    
    private func expandInGenericContext(_ selection: Range<String.Index>) -> Range<String.Index> {
        // Find the generic angle brackets
        let brackets = tokens.filter { $0.kind == .bracket && ($0.value == "<" || $0.value == ">") }
        guard let startBracket = brackets.first(where: { $0.range.lowerBound <= selection.lowerBound }),
              let endBracket = brackets.last(where: { $0.range.upperBound >= selection.upperBound }) else {
            return selection
        }
        
        return startBracket.range.lowerBound..<endBracket.range.upperBound
    }
    
    private func expandInRootContext(_ selection: Range<String.Index>) -> Range<String.Index> {
        // Cursor inside or at boundary of word: expand to that word
        if selection.lowerBound == selection.upperBound {
            if let wordToken = tokens.first(where: { $0.kind == .word && ($0.range.contains(selection.lowerBound) || $0.range.upperBound == selection.lowerBound) }) {
                return wordToken.range
            }
        }
        // 1. Find all word tokens that overlap the selection
        let overlappingWords = tokens.filter { token in
            token.kind == .word && token.range.overlaps(selection)
        }
        if let wordToken = overlappingWords.min(by: { $0.range.lowerBound < $1.range.lowerBound }) {
            return wordToken.range
        }
        // 2. If selection is in whitespace, expand to the next word to the right
        if let wordToken = tokens.first(where: { token in
            token.kind == .word && token.range.lowerBound >= selection.upperBound
        }) {
            return wordToken.range
        }
        // 3. If at the end, expand to the last word to the left
        if let wordToken = tokens.reversed().first(where: { token in
            token.kind == .word && token.range.upperBound <= selection.lowerBound
        }) {
            return wordToken.range
        }
        // Fallback: return selection
        return selection
    }
}

// MARK: -

public struct SourceTextRange: Equatable {
    public let start: SourceTextPosition
    public let end: SourceTextPosition

    public init(start: SourceTextPosition, end: SourceTextPosition) {
        self.start = start
        self.end = end
    }
}

// MARK: -

public struct SourceTextPosition: Equatable {
    public var line: Int
    public var column: Int

    public init(line: Int, column: Int) {
        self.line = line
        self.column = column
    }
}

private func makeRaw(_ string: String) -> (Substring, Substring, Substring)? {
    guard let firstDividerIndex = string.firstIndex(of: "|") else { return nil }
    let beforeFirstDivider = string.prefix(upTo: firstDividerIndex)
    let afterFirstDivider = string[string.index(after: firstDividerIndex)...]
    if let secondDivider = afterFirstDivider.firstIndex(of: "|") {
        return (
            beforeFirstDivider,
            afterFirstDivider[..<secondDivider],
            afterFirstDivider[afterFirstDivider.index(after: secondDivider)...]
        )
    } else {
        return (
            beforeFirstDivider,
            "",
            afterFirstDivider
        )
    }
}

