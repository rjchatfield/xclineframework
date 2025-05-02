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
        // --- Stage 0: Cursor Expansion ---
        if selection.lowerBound == selection.upperBound {
            // Find the word associated with the cursor using root context logic
            // expandInRootContext handles finding the appropriate word or returning selection
            return expandInRootContext(selection)
        }

        // --- Stage 1: Partial Word Expansion ---
        // Check if the current selection is strictly contained within a single word token
        if let containingWord = tokens.first(where: { $0.kind == .word &&
                                                 $0.range.lowerBound <= selection.lowerBound &&
                                                 $0.range.upperBound >= selection.upperBound }) {
             // If the selection is smaller than the containing word, expand to the word boundaries
             if selection != containingWord.range {
                 return containingWord.range // Expand partial word -> full word
             }
             // If selection IS the full word, proceed to context expansion below
        }

        // --- Stage 2: Context-Specific Expansion (String, Array, etc.) ---
        // Now that we handle partial->full word expansion first, we can check contexts.

        // String Context Check
        let quoteTokens = tokens.filter { $0.kind == .quote }
        if let startQuote = quoteTokens.first, let endQuote = quoteTokens.last {
            let fullStringRangeIncludingQuotes = startQuote.range.lowerBound..<endQuote.range.upperBound
            // Check if the *current* selection is within the string bounds (content or quotes)
            if selection.lowerBound >= startQuote.range.lowerBound && selection.upperBound <= endQuote.range.upperBound {
                 // Delegate to string context logic, which now handles word->content->quotes
                 let stringExpansion = expandInStringContext(selection)
                 // Only return if it actually expanded
                 if stringExpansion != selection { return stringExpansion }
                 // If string logic didn't expand (e.g., already at max), fall through
            }
        }

        // Array Context Check
        let arrayExpansion = expandInArrayContext(selection)
        if arrayExpansion != selection { return arrayExpansion }

        // Function Context Check (Assuming expandInFunctionContext returns selection if no expansion)
        let functionExpansion = expandInFunctionContext(selection)
        if functionExpansion != selection { return functionExpansion }

        // Closure Context Check
        let closureExpansion = expandInClosureContext(selection)
        if closureExpansion != selection { return closureExpansion }

        // Generic Context Check
        let genericExpansion = expandInGenericContext(selection)
        if genericExpansion != selection { return genericExpansion }

        // --- Stage 3: Fallback Root Context Expansion ---
        // If no specific context applied or expanded, try root logic again.
        // This might handle cases like selecting across different token types not in a specific context.
        let rootExpansion = expandInRootContext(selection)
        if rootExpansion != selection { return rootExpansion }

        // Final fallback: nearest token if absolutely nothing else expanded
        // Avoid calling findNearestToken if rootExpansion already returned selection
        if rootExpansion == selection {
             return findNearestToken(for: selection)
        } else {
             return rootExpansion // Should be selection if no expansion happened in root context
        }
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
        // Assumes word expansion (cursor->word, partial->word) was handled before this.
        // This function handles: word -> content -> content+quotes
        let quotes = tokens.filter { $0.kind == .quote }
        guard let startQuote = quotes.first, let endQuote = quotes.last else {
            return selection // Should not happen if called within string context check
        }
        let contentStart = startQuote.range.upperBound
        let contentEnd = endQuote.range.lowerBound
        let contentRange = contentStart..<contentEnd
        let fullRange = startQuote.range.lowerBound..<endQuote.range.upperBound

        // If selection is fully within content (could be one word, multiple words, or full content)
        if selection.lowerBound >= contentStart && selection.upperBound <= contentEnd {
             // If it IS the full content range -> expand to include quotes
             if selection == contentRange {
                 return fullRange // Content -> Content+Quotes
             } else {
                 // It's *part* of the content (e.g., a word that was just expanded from partial)
                 // -> expand to full content range
                 return contentRange // Word(s) -> Content
             }
        }

        // If selection includes quotes or is already the full range
        // Check bounds relative to the full range including quotes
        if selection.lowerBound >= startQuote.range.lowerBound && selection.upperBound <= endQuote.range.upperBound {
            // If selection is already the max extent, return it. Otherwise expand to max.
             return fullRange // Expand to/remain at Content+Quotes
        }

        // Fallback: Should ideally not be reached if checks in `expand` are correct.
        return selection
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
        // Pair brackets and handle nested arrays with multi-stage expansion
        let bracketTokens = tokens.filter { $0.kind == .bracket && ($0.value == "[" || $0.value == "]") }
        var stack: [Token] = []
        var pairs: [(open: Token, close: Token)] = []
        for token in bracketTokens {
            if token.value == "[" {
                stack.append(token)
            } else if token.value == "]", let open = stack.popLast() {
                pairs.append((open: open, close: token))
            }
        }
        // Find pairs that enclose the selection
        let enclosingPairs = pairs.filter { pair in
            pair.open.range.lowerBound <= selection.lowerBound &&
            pair.close.range.upperBound >= selection.upperBound
        }
        guard !enclosingPairs.isEmpty else { return selection }
        // Sort by the span of the pair (smallest first) to get innermost first
        let sortedPairs = enclosingPairs.sorted {
            let spanA = completeBuffer.distance(from: $0.open.range.lowerBound, to: $0.close.range.upperBound)
            let spanB = completeBuffer.distance(from: $1.open.range.lowerBound, to: $1.close.range.upperBound)
            return spanA < spanB
        }
        // Iterate through pairs for multi-stage expansion
        for pair in sortedPairs {
            let openLB = pair.open.range.lowerBound
            let openUB = pair.open.range.upperBound
            let closeLB = pair.close.range.lowerBound
            let closeUB = pair.close.range.upperBound
            let contentRange = openUB..<closeLB
            let fullRange = openLB..<closeUB
            // Stage 1: inside content but not entire content
            if selection.lowerBound >= openUB && selection.upperBound <= closeLB {
                if selection == contentRange {
                    // Stage 2: content fully selected -> include brackets
                    return fullRange
                }
                return contentRange
            }
            // Stage 3: if entire pair is already selected, skip to next outer pair
            if selection == fullRange {
                continue
            }
        }
        // Fallback to outermost pair full range
        let outer = sortedPairs.last!
        return outer.open.range.lowerBound..<outer.close.range.upperBound
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
        // --- Cursor Expansion ---
        if selection.lowerBound == selection.upperBound {
            // Find word containing or immediately following cursor
            if let wordToken = tokens.first(where: { $0.kind == .word && ($0.range.contains(selection.lowerBound) || $0.range.upperBound == selection.lowerBound || $0.range.lowerBound == selection.lowerBound) }) {
                 // Added lowerBound check for cursor at start of word
                 return wordToken.range
            }
            // If cursor not in/near word, maybe expand to adjacent non-whitespace token?
            // For now, let later logic handle it or return selection.
             return selection // Return cursor if no word found nearby
        }

        // --- Range Expansion ---
        // If selection is a range:

        // Priority 1: Fully Contained Word
        // Find the smallest word token that *fully contains* the selection.
        if let containingWord = tokens.filter({ $0.kind == .word && $0.range.lowerBound <= selection.lowerBound && $0.range.upperBound >= selection.upperBound }).min(by: { completeBuffer.distance(from: $0.range.lowerBound, to: $0.range.upperBound) < completeBuffer.distance(from: $1.range.lowerBound, to: $1.range.upperBound) }) {
             // Expand selection to the bounds of the word it's inside
             // Note: The main `expand` function already handles partial->full word expansion in Stage 1.
             // This check might be redundant here or could handle edge cases.
             // Let's keep it simple: If it's contained, we probably want the word itself.
             return containingWord.range
        }

        // Priority 2: Overlapping Words
        // Find word tokens that overlap the selection.
        let overlappingWords = tokens.filter { token in
            token.kind == .word && token.range.overlaps(selection)
        }

        // If selection overlaps exactly one word, expand to that word's bounds.
        if overlappingWords.count == 1 {
             // Check if the selection is *smaller* than the word - if so, Stage 1 in `expand` handles it.
             // If selection >= word range, maybe expand outwards?
             // Let's return the word range for simplicity if it overlaps just one.
            return overlappingWords[0].range
        }
        // If selection overlaps multiple words, expand to union of those words?
        if overlappingWords.count > 1 {
             if let firstWord = overlappingWords.min(by: { $0.range.lowerBound < $1.range.lowerBound }),
                let lastWord = overlappingWords.max(by: { $0.range.upperBound < $1.range.upperBound }) {
                 return firstWord.range.lowerBound..<lastWord.range.upperBound
             }
        }


        // Priority 3: Adjacent Word (if selection is in whitespace/non-word)
        // Find the nearest word to the right
        if let nextWord = tokens.first(where: { token in
            token.kind == .word && token.range.lowerBound >= selection.upperBound
        }) {
            // Check distance? Only expand if adjacent?
            if let precedingToken = tokens.last(where: { $0.range.upperBound <= selection.lowerBound }), precedingToken.range.upperBound == selection.lowerBound {
                 // Selection might start right after a token. Check what's between selection end and next word.
                 let gap = completeBuffer[selection.upperBound..<nextWord.range.lowerBound]
                 if gap.allSatisfy({ $0.isWhitespace }) {
                      // Expand selection in whitespace to the next word
                      // return nextWord.range // Option 1: Just the word
                      return selection.lowerBound..<nextWord.range.upperBound // Option 2: Include whitespace + word
                 }
            } else if selection.upperBound == nextWord.range.lowerBound { // Directly adjacent
                  return selection.lowerBound..<nextWord.range.upperBound // Include word
            }
             // If not clearly adjacent whitespace, don't expand yet.
        }

        // Find the nearest word to the left
         if let prevWord = tokens.reversed().first(where: { token in
             token.kind == .word && token.range.upperBound <= selection.lowerBound
         }) {
             if let followingToken = tokens.first(where: { $0.range.lowerBound >= selection.upperBound }), followingToken.range.lowerBound == selection.upperBound {
                  let gap = completeBuffer[prevWord.range.upperBound..<selection.lowerBound]
                  if gap.allSatisfy({ $0.isWhitespace }) {
                       // return prevWord.range // Option 1
                       return prevWord.range.lowerBound..<selection.upperBound // Option 2: Include word + whitespace
                  }
             } else if selection.lowerBound == prevWord.range.upperBound { // Directly adjacent
                  return prevWord.range.lowerBound..<selection.upperBound // Include word
             }
              // If not clearly adjacent whitespace, don't expand yet.
         }

        // Fallback: return selection if no expansion rule applied in root context
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

