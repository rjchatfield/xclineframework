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
        // let initialDesc = Buffer(completeBuffer: completeBuffer, selections: [SourceTextRange(range: selection, buffer: completeBuffer)]).rawDescription
        // print("[expand] Input: \(initialDesc)")
        // --- Stage 0: Cursor Expansion ---
        if selection.lowerBound == selection.upperBound {
            let result = expandInRootContext(selection)
            // let resultDesc = Buffer(completeBuffer: completeBuffer, selections: [SourceTextRange(range: result, buffer: completeBuffer)]).rawDescription
            // print("[expand] Stage 0 (Cursor) -> \(resultDesc)")
            return result
        }

        // --- Stage 1: Partial Word Expansion ---
        if let containingWord = tokens.first(where: { $0.kind == .word &&
                                                 $0.range.lowerBound <= selection.lowerBound &&
                                                 $0.range.upperBound >= selection.upperBound }) {
             if selection != containingWord.range {
                // let resultDesc = Buffer(completeBuffer: completeBuffer, selections: [SourceTextRange(range: containingWord.range, buffer: completeBuffer)]).rawDescription
                // print("[expand] Stage 1 (Partial Word) -> \(resultDesc)")
                 return containingWord.range // Expand partial word -> full word
             }
        }
        
        // --- Stage 1.5: Chain Expansion ---
        let chainExpansion = expandChainBackward(selection)
        if chainExpansion != selection {
            // let resultDesc = Buffer(completeBuffer: completeBuffer, selections: [SourceTextRange(range: chainExpansion, buffer: completeBuffer)]).rawDescription
            // print("[expand] Stage 1.5 (Chain) -> \(resultDesc)")
            return chainExpansion // Return if chain expansion occurred
        }

        // --- Stage 2: Context-Specific Expansion (String, Array, etc.) ---
        var contextResult: Range<String.Index>? = nil
        var isPotentiallyInClosureSignature = false
        // print("[expand S2] Checking for potential closure signature...")
        
        // New check: Find nearest preceding '{' and subsequent 'in' or '}'
        if let openBraceIndex = tokens.lastIndex(where: { $0.kind == .bracket && $0.value == "{" && $0.range.lowerBound <= selection.lowerBound }) {
            let openBrace = tokens[openBraceIndex]
            if let endSignatureTokenIndex = tokens.firstIndex(where: {
                ($0.kind == .word && $0.value == "in" || $0.kind == .bracket && $0.value == "}")
                && $0.range.lowerBound >= selection.lowerBound
                && $0.range.lowerBound > openBrace.range.lowerBound // Ensure after the found open brace
            }) {
                let endSignatureToken = tokens[endSignatureTokenIndex]
                // Selection ends before or at the start of the 'in'/'}'?
                if selection.upperBound <= endSignatureToken.range.lowerBound {
                    // print("[expand S2] Found preceding { and subsequent in/}. Potential closure signature.")
                    isPotentiallyInClosureSignature = true
                } else {
                    // print("[expand S2] Found { and in/}, but selection extends beyond 'in'. Not signature.")
                }
            } else {
                // print("[expand S2] Found preceding {, but no subsequent 'in' or '}'.")
            }
        } else {
            // print("[expand S2] No preceding { found.")
        }

        // Try Closure Context FIRST if applicable
        if isPotentiallyInClosureSignature {
            // print("[expand S2] Attempting Closure Context expansion.")
             let closureExpansion = expandInClosureContext(selection)
             if closureExpansion != selection { 
                // print("[expand S2] Closure Context DID expand.")
                  contextResult = closureExpansion
             } else {
                // print("[expand S2] Closure Context returned no change.")
             }
        }

        // Dictionary Context Check (NEW - Add this before others like String/Array)
        if contextResult == nil {
            // print("[expand S2] Attempting Dictionary Context expansion.")
            if let dictExpansion = expandInDictionaryContext(selection) {
                 if dictExpansion != selection { 
                    // print("[expand] Stage 2 (Dictionary Context)")
                    contextResult = dictExpansion
                 } else {
                    // print("[expand S2] Dictionary Context returned no change.")
                 }
            } // expandInDictionaryContext returns optional now
        }

        // String Context Check (Only if no context found yet)
        if contextResult == nil {
            // print("[expand S2] Attempting String Context expansion.")
             let quoteTokens = tokens.filter { $0.kind == .quote }
             if let startQuote = quoteTokens.first, let endQuote = quoteTokens.last {
                 if selection.lowerBound >= startQuote.range.lowerBound && selection.upperBound <= endQuote.range.upperBound {
                      let stringExpansion = expandInStringContext(selection)
                      if stringExpansion != selection { 
                        // print("[expand] Stage 2 (String Context)")
                         contextResult = stringExpansion
                      }
                 }
             }
        }
        // Array Context Check (Only if no context found yet)
        if contextResult == nil {
            // print("[expand S2] Attempting Array Context expansion.")
             let arrayExpansion = expandInArrayContext(selection)
             if arrayExpansion != selection { 
                // print("[expand] Stage 2 (Array Context)")
                  contextResult = arrayExpansion
             }
        }
        // Function Context Check (Only if no context found yet AND *not* in a closure signature)
        if contextResult == nil && !isPotentiallyInClosureSignature {
            // print("[expand S2] Attempting Function Context expansion.")
             let functionExpansion = expandInFunctionContext(selection)
             if functionExpansion != selection { 
                // print("[expand] Stage 2 (Function Context)")
                  contextResult = functionExpansion
             }
        } else if contextResult == nil && isPotentiallyInClosureSignature {
            // print("[expand S2] Skipping Function Context check because potential closure signature found.")
        }
        // Generic Context Check (Only if no context found yet)
         if contextResult == nil {
            // print("[expand S2] Attempting Generic Context expansion.")
              let genericExpansion = expandInGenericContext(selection)
              if genericExpansion != selection { 
                // print("[expand] Stage 2 (Generic Context)")
                   contextResult = genericExpansion
              }
         }
         
        // If no specific context handled it, *maybe* try Closure again for simple { } cases?
        // No, let root context handle simple block expansion if needed.

        // Return if context expansion happened
        if let contextResult = contextResult {
            // let resultDesc = Buffer(completeBuffer: completeBuffer, selections: [SourceTextRange(range: contextResult, buffer: completeBuffer)]).rawDescription
            // print("[expand] Stage 2 -> \(resultDesc)")
             return contextResult
        }

        // --- Stage 2.5: Base Type Expansion ---
        if let baseTypeExpansion = expandBaseTypeIfGenericSelected(selection) {
            // let resultDesc = Buffer(completeBuffer: completeBuffer, selections: [SourceTextRange(range: baseTypeExpansion, buffer: completeBuffer)]).rawDescription
            // print("[expand] Stage 2.5 (Base Type) -> \(resultDesc)")
             return baseTypeExpansion
        }

        // --- Stage 3: Fallback Root Context Expansion ---
        let rootExpansion = expandInRootContext(selection)
        if rootExpansion != selection { 
            // let resultDesc = Buffer(completeBuffer: completeBuffer, selections: [SourceTextRange(range: rootExpansion, buffer: completeBuffer)]).rawDescription
            // print("[expand] Stage 3 (Root Fallback) -> \(resultDesc)")
             return rootExpansion
        }

        // Final fallback: nearest token
        if rootExpansion == selection {
             let nearest = findNearestToken(for: selection)
             if nearest != selection {
                // let resultDesc = Buffer(completeBuffer: completeBuffer, selections: [SourceTextRange(range: nearest, buffer: completeBuffer)]).rawDescription
                // print("[expand] Stage 4 (Nearest Token) -> \(resultDesc)")
             }
             return nearest == selection ? selection : nearest
        } else {
             // Should not be reached if rootExpansion != selection check above is correct
             return rootExpansion
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
    
    private func expandInStringContext(_ selection: Range<String.Index>) -> Range<String.Index> {
        // Find the nearest enclosing quotes for the current selection
        let precedingQuotes = tokens.filter { $0.kind == .quote && $0.range.upperBound <= selection.lowerBound }.sorted { $0.range.lowerBound > $1.range.lowerBound }
        let followingQuotes = tokens.filter { $0.kind == .quote && $0.range.lowerBound >= selection.upperBound }.sorted { $0.range.lowerBound < $1.range.lowerBound }

        guard let startQuote = precedingQuotes.first, 
              let endQuote = followingQuotes.first else {
            // Cannot find enclosing quotes for this selection, maybe it spans across strings or isn't inside one
            return selection
        }

        // Define ranges based on the *closest* surrounding quotes
        let contentStart = startQuote.range.upperBound
        let contentEnd = endQuote.range.lowerBound
        
        // Ensure content range is valid (start before end)
        guard contentStart <= contentEnd else { return selection }
        let contentRange = contentStart..<contentEnd
        
        // Ensure full range is valid
        guard startQuote.range.lowerBound <= endQuote.range.upperBound else { return selection }
        let fullRange = startQuote.range.lowerBound..<endQuote.range.upperBound

        // --- Expansion Logic using localized ranges ---

        // Stage 1: Selection is PART of the content -> Expand to FULL content (between these quotes)
        // Check if selection is strictly within the content range defined by the closest quotes
        if selection.lowerBound >= contentStart && selection.upperBound <= contentEnd {
            // If it's already the full content -> Expand to include quotes (Stage 2)
            if selection == contentRange {
                 // print("[strCtx] Content -> Full")
                return fullRange
            } else {
                // It's part of the content -> Expand to the full content (between *these* quotes)
                 // print("[strCtx] Partial Content -> Full Content")
                return contentRange
            }
        }

        // Stage 2: Selection is the FULL content (or already includes quotes) -> Expand/Remain at FULL range (with quotes)
        // Check if selection is within the full range defined by closest quotes
        if selection.lowerBound >= startQuote.range.lowerBound && selection.upperBound <= endQuote.range.upperBound {
             // print("[strCtx] Already Full or Touching Quotes -> Full")
            // If selection is already the max extent (fullRange), return it. Otherwise expand to max.
            return fullRange
        }

        // Fallback: Selection is outside the identified closest string bounds
         // print("[strCtx] Fallback -> No Change")
        return selection
    }
    
    private func expandInFunctionContext(_ selection: Range<String.Index>) -> Range<String.Index> {
        // 1. Find the innermost parentheses pair enclosing the selection.
        guard let (openParen, closeParen, contentRange) = findInnermostEnclosingPair(selection: selection, openChar: "(", closeChar: ")") else {
            // Selection might be on the function name itself or outside parentheses.
            // Let other expansion logic handle this.
            return selection
        }
        let fullRange = openParen.range.lowerBound..<closeParen.range.upperBound

        // --- Expansion Stages within Parentheses ---

        // Stage 4: Selection is already the full range (including parens)
        if selection == fullRange {
            return selection // Cannot expand further in this context
        }

        // Stage 3: Selection is the content range (all parameters) -> Expand to include parens
        if selection == contentRange {
            return fullRange
        }

        // --- Stages within the contentRange ---
        // Check if selection is strictly within the content (not touching parens)
        if selection.lowerBound >= contentRange.lowerBound && selection.upperBound <= contentRange.upperBound {
            // Identify the parameter(s) the selection belongs to
            let parameterRanges = findParameterRanges(within: contentRange) // Use helper

            // Find which parameter range(s) the selection overlaps
            let overlappingParams = parameterRanges.filter { $0.range.overlaps(selection) }

            if overlappingParams.count == 1 {
                let param = overlappingParams[0]
                // Selection is within a single parameter

                // Stage 2: Selection is the full parameter -> Expand to all parameters (contentRange)
                if selection == param.range {
                     // Ensure there's actually content to expand to, otherwise stay put
                     return contentRange.isEmpty ? selection : contentRange
                }

                // Stage 1: Selection is part of the parameter (name/label or type) -> Expand to full parameter
                // Find the range of the label/name part and the type part
                if let (nameLabelRange, typeRange) = findParameterComponents(paramRange: param.range) {
                     // Check if selection overlaps/equals name/label part or type part
                     // Use precise check: selection must be fully contained within either part
                    let selectionInName = nameLabelRange.lowerBound <= selection.lowerBound && nameLabelRange.upperBound >= selection.upperBound
                    let selectionInType = typeRange.lowerBound <= selection.lowerBound && typeRange.upperBound >= selection.upperBound

                    if selectionInName || selectionInType {
                        // If selection matches name/label OR type -> expand to full parameter
                        return param.range
                    }
                }
                
                // Fallback: If selection is within a param but not clearly name/type (e.g., colon, whitespace)
                // -> expand to the full parameter range.
                return param.range

            } else if overlappingParams.count > 1 {
                // Selection spans multiple parameters -> Expand to all parameters (contentRange)
                 return contentRange.isEmpty ? selection : contentRange
            } else if !contentRange.isEmpty {
                 // Selection is in whitespace/comma between parameters -> Expand to all parameters
                 return contentRange
            }
            // If contentRange is empty and selection isn't overlapping anything, return selection
             return selection
        }

        // --- Selection touching or outside contentRange but within fullRange ---
        // Example: Selecting just the open paren, or from outside into the first param.
        // Generally, expand to include the full content.
        if !contentRange.isEmpty {
             return contentRange
        }

        return selection // Default fallback if nothing else matched
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
        // Hybrid approach: Add back intermediate steps
        // print("[closureCtx] Running Hybrid Logic")

        // 1. Find preceding {
        guard let openBraceIndex = tokens.lastIndex(where: { $0.kind == .bracket && $0.value == "{" && $0.range.lowerBound <= selection.lowerBound }),
              let openBrace = Optional(tokens[openBraceIndex])
        else {
            // print("[closureCtx] Hybrid: Cannot find preceding {")
            return selection
        }

        // 2. Find subsequent 'in' keyword 
        guard let inTokenIndex = tokens.firstIndex(where: { $0.kind == .word && $0.value == "in" && $0.range.lowerBound >= selection.lowerBound }),
              let inToken = Optional(tokens[inTokenIndex])
        else {
            // print("[closureCtx] Hybrid: Cannot find subsequent 'in' keyword")
            return selection
        }
        
        // 3. Identify Signature Components
        let signatureEnd = inToken.range.lowerBound
        let signatureTokens = tokens.filter { $0.range.lowerBound >= openBrace.range.upperBound && $0.range.upperBound <= signatureEnd }
        
        let paramSearchRange = openBrace.range.upperBound..<signatureEnd
        var parameterParenthesesRange: Range<String.Index>? = nil
        var parametersContentRange: Range<String.Index>? = nil
        var parameterRanges: [ParameterInfo] = []
        var returnTypeRange: Range<String.Index>? = nil
        var arrowToken: Token? = nil

        // Find arrow token
        arrowToken = signatureTokens.first(where: { $0.kind == .arrow })

        // Find Parameter tokens (before arrow or end)
        let paramEndBoundary = arrowToken?.range.lowerBound ?? signatureEnd
        let paramTokens = signatureTokens.filter { $0.range.upperBound <= paramEndBoundary }

        if let openParen = paramTokens.first(where: { $0.kind == .bracket && $0.value == "(" }),
           let openParenIndex = paramTokens.firstIndex(of: openParen),
           let closeParen = findMatchingBrace(startIndex: openParenIndex, tokens: paramTokens), 
           let closeParenIndex = paramTokens.firstIndex(of: closeParen),
           closeParenIndex > openParenIndex {
            parameterParenthesesRange = openParen.range.lowerBound..<closeParen.range.upperBound
            parametersContentRange = openParen.range.upperBound..<closeParen.range.lowerBound
             if let content = parametersContentRange, !content.isEmpty {
                 parameterRanges = findParameterRanges(within: content)
             }
        } else {
             let effectiveParamSearchRange = openBrace.range.upperBound..<paramEndBoundary
             if !effectiveParamSearchRange.isEmpty {
                 parametersContentRange = effectiveParamSearchRange
                 parameterRanges = findParameterRanges(within: effectiveParamSearchRange)
             }
        }

        // Find Return Type Range (after arrow, before in)
        if let arrow = arrowToken {
             let returnStart = arrow.range.upperBound
             let returnEnd = signatureEnd
             let potentialReturnRange = returnStart..<returnEnd
             // Trim whitespace (optional but good)
             if let trimmedStart = completeBuffer.rangeOfCharacter(from: .whitespacesAndNewlines.inverted, options: [], range: potentialReturnRange)?.lowerBound,
                let trimmedEnd = completeBuffer.rangeOfCharacter(from: .whitespacesAndNewlines.inverted, options: .backwards, range: potentialReturnRange)?.upperBound,
                trimmedStart < trimmedEnd {
                 returnTypeRange = trimmedStart..<trimmedEnd
             }
        }
        
        // Determine the full range covered by parameters (incl. parens if they exist)
        let fullParameterSectionRange = parameterParenthesesRange ?? parametersContentRange

        // --- Expansion Logic ---

        // STEP 1: Name/Type -> Full Parameter 
        var step1Applied = false
        var selectedFullParameterOnlyName = false // Track if selection matches a name-only param
        for param in parameterRanges {
             let components = findParameterComponents(paramRange: param.range)
             
             if let (nameLabelRange, typeRange) = components {
                 let selectionInName = nameLabelRange.overlaps(selection) && !(selection.lowerBound < nameLabelRange.lowerBound || selection.upperBound > nameLabelRange.upperBound)
                 let selectionInType = typeRange.overlaps(selection) && !(selection.lowerBound < typeRange.lowerBound || selection.upperBound > typeRange.upperBound)

                 if (selectionInName || selectionInType) && selection != param.range {
                    // print("[closureCtx] Hybrid Step 1: Name/Type -> Full Param")
                     step1Applied = true
                     return param.range
                 }
             } else if param.range == selection { 
                 // Check explicitly if components were nil (meaning only name was found)
                 if components == nil {
                    // print("[closureCtx] Hybrid Step 1: Detected selection matches name-only param: \(param.range)")
                    selectedFullParameterOnlyName = true
                 }
             } else if param.range.overlaps(selection) && selection != param.range {
                 // Selection is PART of a name-only parameter
                // print("[closureCtx] Hybrid Step 1: Partial Name-Only Param -> Full Param")
                 step1Applied = true
                 return param.range 
             }
        }
        
        // STEP 2: Expand Full Parameter -> All Parameters
        // Skip if we just selected a full name-only parameter (allow Step 5 to handle it)
        if !step1Applied && !selectedFullParameterOnlyName, 
           let paramContent = parametersContentRange, 
           !paramContent.isEmpty, 
           parameterRanges.contains(where: { $0.range == selection })
        {
            // print("[closureCtx] Hybrid Step 2: Full Param -> All Params Content")
            return paramContent
        }
        
        // STEP 3: Expand Parameter Content -> Include Parentheses
        if let parens = parameterParenthesesRange, // Only applies if parens exist
           let content = parametersContentRange, 
           selection == content // Selection must exactly match the content range
        {
            // print("[closureCtx] Hybrid Step 3: Param Content -> Include Parens")
             return parens
        }
        
        // STEP 4: Expand Parameters/Parens -> Include Return Type
        if let fullParamRange = fullParameterSectionRange,
           selection == fullParamRange, 
           let retRange = returnTypeRange, 
           let arrow = arrowToken
        {
            // print("[closureCtx] Hybrid Step 4: Params/Parens -> Include Return")
             return fullParamRange.lowerBound..<retRange.upperBound
        }
        
        // STEP 5: Expand Full Signature -> Include 'in'
        // Calculate the full signature range (start of params/parens to end of return type, or just params if no return)
        let fullSignatureRange: Range<String.Index>? = {
            if let fullParamRange = fullParameterSectionRange {
                 if let retRange = returnTypeRange {
                     return fullParamRange.lowerBound..<retRange.upperBound
                 } else {
                     return fullParamRange
                 }
            }
            return nil
        }()
        
        // Condition: Selection is the full signature OR Selection is the only name-only param
        let selectionIsFullSignature = (fullSignatureRange != nil && selection == fullSignatureRange!)
        let selectionIsOnlyNameOnlyParam = selectedFullParameterOnlyName && parameterRanges.count == 1 && parameterParenthesesRange == nil && returnTypeRange == nil

        if selectionIsFullSignature || selectionIsOnlyNameOnlyParam 
        {
             let targetStartRange = selectedFullParameterOnlyName ? selection : fullSignatureRange! // Adjust target based on trigger
            // let selDesc = Buffer(completeBuffer: completeBuffer, selections: [SourceTextRange(range: selection, buffer: completeBuffer)]).rawDescription
            // let sigDesc = fullSignatureRange != nil ? Buffer(completeBuffer: completeBuffer, selections: [SourceTextRange(range: fullSignatureRange!, buffer: completeBuffer)]).rawDescription : "<nil>"
            // print("[closureCtx] Hybrid Step 5: Checking selection '\(selDesc)' against sigRange '\(sigDesc)' -> Triggered: \(selectionIsFullSignature || selectionIsOnlyNameOnlyParam)") // RESTORED
            // print("[closureCtx] Hybrid Step 5: Full Signature -> Include 'in'")
             let resultRange = targetStartRange.lowerBound..<inToken.range.upperBound
            // let resultDesc = Buffer(completeBuffer: completeBuffer, selections: [SourceTextRange(range: resultRange, buffer: completeBuffer)]).rawDescription
            // print("[closureCtx] Hybrid Step 5: Returning -> \(resultDesc) [Range: \(resultRange)]") // ADDED RANGE DETAIL
             return resultRange
        }

        // --- FALLBACK --- 
        // print("[closureCtx] Hybrid: No applicable expansion step found -> No Change")
        return selection 
    }
    
    private func expandInGenericContext(_ selection: Range<String.Index>) -> Range<String.Index> {
        // 1. Find the innermost angle bracket pair enclosing the selection.
        guard let (openBracket, closeBracket, contentRange) = findInnermostEnclosingPair(selection: selection, openChar: "<", closeChar: ">") else {
             return selection // Not inside <> or selection doesn't allow finding a pair
        }
        let fullRange = openBracket.range.lowerBound..<closeBracket.range.upperBound

        // --- Expansion Stages within Angle Brackets ---

        // Stage 4: Selection is already the full range (including brackets)
        if selection == fullRange {
            return selection // Cannot expand further *within* this context, main `expand` handles base type
        }

        // Stage 3: Selection is the content range (all arguments) -> Expand to include brackets
        if selection == contentRange {
             return fullRange
        }

        // --- Stages within the contentRange ---
        if selection.lowerBound >= contentRange.lowerBound && selection.upperBound <= contentRange.upperBound {
            // Identify the generic argument(s) the selection belongs to
            let argumentRanges = findGenericArgumentRanges(within: contentRange) // Use helper

            // Find which argument range(s) the selection overlaps
            let overlappingArgs = argumentRanges.filter { $0.overlaps(selection) }

            if overlappingArgs.count == 1 {
                let argRange = overlappingArgs[0]
                // Selection is within a single argument

                // Stage 2: Selection is the full argument -> Expand to all arguments (contentRange)
                if selection == argRange {
                     return contentRange.isEmpty ? selection : contentRange
                }

                // Stage 1: Selection is part of the argument -> Expand to full argument
                // (Assumes inner nested generics are handled by recursive calls or subsequent expansions)
                // If the selection is smaller than the argument range it overlaps, expand to the full argument range.
                return argRange

            } else if overlappingArgs.count > 1 {
                // Selection spans multiple arguments -> Expand to all arguments (contentRange)
                 return contentRange.isEmpty ? selection : contentRange
            } else if !contentRange.isEmpty {
                 // Selection is in whitespace/comma between args -> Expand to all arguments
                 return contentRange
            }
             return selection // Empty content range
        }

        // --- Selection touching or outside contentRange but within fullRange ---
        if !contentRange.isEmpty {
             return contentRange
        }

        return selection // Default fallback
    }
    
    private func expandInRootContext(_ selection: Range<String.Index>) -> Range<String.Index> {
        let initialDesc = Buffer(completeBuffer: completeBuffer, selections: [SourceTextRange(range: selection, buffer: completeBuffer)]).rawDescription
        // print("[rootCtx] Input: \(initialDesc)")
        // --- Cursor Expansion ---
        if selection.lowerBound == selection.upperBound {
            if let wordToken = tokens.first(where: { $0.kind == .word && ($0.range.contains(selection.lowerBound) || $0.range.upperBound == selection.lowerBound || $0.range.lowerBound == selection.lowerBound) }) {
                 // print("[rootCtx] Cursor -> Word ('\(wordToken.value)')")
                 return wordToken.range
            }
             // print("[rootCtx] Cursor -> No Change")
             return selection // Return cursor if no word found nearby
        }

        // --- Range Expansion ---

        // Priority 1: Selection within a single Word -> Expand to full word
        if let containingWord = tokens.first(where: { $0.kind == .word &&
                                                 $0.range.lowerBound <= selection.lowerBound &&
                                                 $0.range.upperBound >= selection.upperBound }) {
             if selection != containingWord.range {
                // print("[rootCtx] Prio 1 (Inside Word) -> Full Word ('\(containingWord.value)')")
                 return containingWord.range
             }
        }

        // Priority 2: Overlapping Multiple Words -> Union
        let overlappingWords = tokens.filter { token in
            token.kind == .word && token.range.overlaps(selection)
        }
        if overlappingWords.count > 1 {
             if let firstWord = overlappingWords.min(by: { $0.range.lowerBound < $1.range.lowerBound }),
                let lastWord = overlappingWords.max(by: { $0.range.upperBound < $1.range.upperBound }) {
                  let unionRange = firstWord.range.lowerBound..<lastWord.range.upperBound
                  if selection != unionRange {
                      // print("[rootCtx] Prio 2 (Overlap Words) -> Union ('\(completeBuffer[unionRange])')")
                      return unionRange
                  }
             }
        }

        // Priority 3: Adjacent Word Expansion (Whitespace selection)
        let selectionText = completeBuffer[selection]
        if selectionText.allSatisfy({ $0.isWhitespace }) {
            if let nextWord = tokens.first(where: { $0.kind == .word && $0.range.lowerBound == selection.upperBound }) {
                 // print("[rootCtx] Prio 3 (Whitespace) -> Include Next Word ('\(nextWord.value)')")
                 return selection.lowerBound..<nextWord.range.upperBound
            }
            if let prevWord = tokens.last(where: { $0.kind == .word && $0.range.upperBound == selection.lowerBound }) {
                 // print("[rootCtx] Prio 3 (Whitespace) -> Include Prev Word ('\(prevWord.value)')")
                 return prevWord.range.lowerBound..<selection.upperBound
            }
        }
        // print("[rootCtx] Fallback -> No Change")
        // Fallback: No root expansion rule applied
        return selection
    }

    // MARK: - Expansion Helpers

    private func findInnermostEnclosingPair(selection: Range<String.Index>, openChar: Character, closeChar: Character) -> (open: Token, close: Token, content: Range<String.Index>)? {
        let bracketTokens = tokens.filter { $0.kind == .bracket && ($0.value == String(openChar) || $0.value == String(closeChar)) }
        var stack: [Token] = []
        var pairs: [(open: Token, close: Token)] = []
        
        for token in bracketTokens {
            if token.value == String(openChar) {
                stack.append(token)
            } else if token.value == String(closeChar), let open = stack.popLast() {
                // Ensure the pair actually encloses the selection bounds
                if open.range.lowerBound < selection.lowerBound && // Paren must be strictly before selection start
                   token.range.upperBound > selection.upperBound { // Paren must be strictly after selection end
                     pairs.append((open: open, close: token))
                } else if open.range.lowerBound == selection.lowerBound && token.range.upperBound == selection.upperBound {
                     // Handle case where selection *is* the brackets themselves maybe?
                     // For now, focus on enclosure.
                }
            }
        }

        guard !pairs.isEmpty else { return nil }
        
        // Sort by span to find the smallest enclosing pair (innermost)
        let sortedPairs = pairs.sorted {
            completeBuffer.distance(from: $0.open.range.lowerBound, to: $0.close.range.upperBound) <
            completeBuffer.distance(from: $1.open.range.lowerBound, to: $1.close.range.upperBound)
        }
        
        guard let innermost = sortedPairs.first else { return nil }
        let contentRange = innermost.open.range.upperBound..<innermost.close.range.lowerBound
        return (innermost.open, innermost.close, contentRange)
    }

    struct ParameterInfo {
         let range: Range<String.Index>
    }

    private func findParameterRanges(within contentRange: Range<String.Index>) -> [ParameterInfo] {
        guard !contentRange.isEmpty else { return [] }
        var parameterRanges: [ParameterInfo] = []
        // Get tokens strictly within the content range, excluding outer brackets
        let relevantTokens = tokens.filter { $0.range.lowerBound >= contentRange.lowerBound && $0.range.upperBound <= contentRange.upperBound }
        guard !relevantTokens.isEmpty else { return [] }

        var currentParamStart = contentRange.lowerBound // Start from the beginning of content range
        var searchStart = 0 // Index within relevantTokens

        for i in searchStart..<relevantTokens.count {
            let token = relevantTokens[i]
            if token.kind == .comma {
                let paramEnd = token.range.lowerBound // End just before comma
                // Trim trailing whitespace from paramEnd backwards
                 let trimmedEnd = completeBuffer.rangeOfCharacter(from: CharacterSet.whitespacesAndNewlines.inverted, options: .backwards, range: currentParamStart..<paramEnd)?.upperBound ?? currentParamStart // Use currentParamStart if only whitespace

                if currentParamStart < trimmedEnd { // Avoid adding empty ranges
                     parameterRanges.append(ParameterInfo(range: currentParamStart..<trimmedEnd))
                }

                // Start next parameter after comma, trimming leading whitespace
                let nextParamStartIndex = token.range.upperBound
                currentParamStart = completeBuffer.rangeOfCharacter(from: CharacterSet.whitespacesAndNewlines.inverted, options: [], range: nextParamStartIndex..<contentRange.upperBound)?.lowerBound ?? contentRange.upperBound // Use end if only whitespace remains
                searchStart = i + 1
            }
        }
        
        // Add the last parameter (from last comma or start, up to the end of contentRange)
        let lastParamEnd = contentRange.upperBound
        // Trim trailing whitespace from the end of the *entire* content range potentially? No, just for the last param.
        let trimmedLastEnd = completeBuffer.rangeOfCharacter(from: CharacterSet.whitespacesAndNewlines.inverted, options: .backwards, range: currentParamStart..<lastParamEnd)?.upperBound ?? currentParamStart

        if currentParamStart < trimmedLastEnd { // Avoid adding empty range if trailing comma or only whitespace
            parameterRanges.append(ParameterInfo(range: currentParamStart..<trimmedLastEnd))
        }

        return parameterRanges
    }

    private func findParameterComponents(paramRange: Range<String.Index>) -> (nameLabel: Range<String.Index>, type: Range<String.Index>)? {
        let paramTokens = tokens.filter { paramRange.overlaps($0.range) && $0.range.lowerBound >= paramRange.lowerBound && $0.range.upperBound <= paramRange.upperBound } // Tokens strictly within the param range
         guard let colonToken = paramTokens.first(where: { $0.kind == .colon }) else {
             // No colon found. Could be a closure parameter name without type?
             // If there's just one word, assume it's the name/label part? Risky.
             // For robust parameter handling, assume colon is needed to separate.
             return nil
         }

         // Everything from start of param range up to colon is name/label part
         let nameLabelEnd = colonToken.range.lowerBound
         // Trim trailing whitespace from name/label part
         let trimmedNameLabelEnd = completeBuffer.rangeOfCharacter(from: CharacterSet.whitespacesAndNewlines.inverted, options: .backwards, range: paramRange.lowerBound..<nameLabelEnd)?.upperBound ?? paramRange.lowerBound // Use start if only whitespace
         let nameLabelRange = paramRange.lowerBound..<trimmedNameLabelEnd

         // Everything from after colon to end of param range is type part
         let typeStart = colonToken.range.upperBound
         // Trim leading whitespace from type part
         let trimmedTypeStart = completeBuffer.rangeOfCharacter(from: CharacterSet.whitespacesAndNewlines.inverted, options: [], range: typeStart..<paramRange.upperBound)?.lowerBound ?? paramRange.upperBound // Use end if only whitespace
         let typeRange = trimmedTypeStart..<paramRange.upperBound

         // Ensure components are not empty after trimming
         guard nameLabelRange.lowerBound < nameLabelRange.upperBound, typeRange.lowerBound < typeRange.upperBound else { return nil }

         return (nameLabelRange, typeRange)
    }

    // Helper to find ranges of top-level arguments within generic brackets, respecting nesting.
    private func findGenericArgumentRanges(within contentRange: Range<String.Index>) -> [Range<String.Index>] {
        guard !contentRange.isEmpty else { return [] }
        var argumentRanges: [Range<String.Index>] = []
        let relevantTokens = tokens.filter { $0.range.lowerBound >= contentRange.lowerBound && $0.range.upperBound <= contentRange.upperBound }
        guard !relevantTokens.isEmpty else { return [] }

        var currentArgStart = contentRange.lowerBound
        var bracketDepth = 0

        for token in relevantTokens {
            if token.kind == .bracket && token.value == "<" {
                bracketDepth += 1
            } else if token.kind == .bracket && token.value == ">" {
                bracketDepth -= 1
            } else if token.kind == .comma && bracketDepth == 0 {
                // Found a top-level comma separating arguments
                let argEnd = token.range.lowerBound
                // Trim trailing whitespace (optional, but good practice)
                let trimmedEnd = completeBuffer.rangeOfCharacter(from: CharacterSet.whitespacesAndNewlines.inverted, options: .backwards, range: currentArgStart..<argEnd)?.upperBound ?? currentArgStart
                if currentArgStart < trimmedEnd {
                    argumentRanges.append(currentArgStart..<trimmedEnd)
                }
                // Start next argument after comma, trimming leading whitespace
                let nextArgStartIndex = token.range.upperBound
                currentArgStart = completeBuffer.rangeOfCharacter(from: CharacterSet.whitespacesAndNewlines.inverted, options: [], range: nextArgStartIndex..<contentRange.upperBound)?.lowerBound ?? contentRange.upperBound
            }
        }

        // Add the last argument
        let lastArgEnd = contentRange.upperBound
        let trimmedLastEnd = completeBuffer.rangeOfCharacter(from: CharacterSet.whitespacesAndNewlines.inverted, options: .backwards, range: currentArgStart..<lastArgEnd)?.upperBound ?? currentArgStart
        if currentArgStart < trimmedLastEnd {
            argumentRanges.append(currentArgStart..<trimmedLastEnd)
        }

        return argumentRanges
    }
    
    // After selecting the full generic part like `<String, Int>`, expand to include the base type like `Dictionary`.
    private func expandBaseTypeIfGenericSelected(_ selection: Range<String.Index>) -> Range<String.Index>? {
         // Check if the selection exactly matches a <...> range defined by tokens.
         guard let firstToken = tokens.first(where: { $0.range.lowerBound == selection.lowerBound }),
               let lastToken = tokens.last(where: { $0.range.upperBound == selection.upperBound }),
               firstToken.kind == .bracket, firstToken.value == "<",
               lastToken.kind == .bracket, lastToken.value == ">" else {
             return nil // Selection is not exactly a <...> range
         }

         // Find the token immediately preceding the opening bracket.
         if let firstBracketIndex = tokens.firstIndex(where: { $0.range.lowerBound == selection.lowerBound }),
            firstBracketIndex > 0 {
              let precedingToken = tokens[firstBracketIndex - 1]
              // Check if the preceding token is a word (the base type name).
              // Also check if it's directly adjacent (no whitespace tokens in between)? Assumed for now.
              if precedingToken.kind == .word && precedingToken.range.upperBound == firstToken.range.lowerBound {
                   // Expand to include the base type name.
                   return precedingToken.range.lowerBound..<selection.upperBound
              }
         }

         return nil // No preceding base type found or not adjacent
    }

    private func tokens(in range: Range<String.Index>) -> [Token] {
         tokens.filter { range.overlaps($0.range) }
    }

    // NEW HELPER FUNCTION for chain expansion logic
    private func expandChainBackward(_ selection: Range<String.Index>) -> Range<String.Index> {
        let initialDesc = Buffer(completeBuffer: completeBuffer, selections: [SourceTextRange(range: selection, buffer: completeBuffer)]).rawDescription
        // print("[chainBwd] Input: \(initialDesc)")
        // --- Step 1 (Logic A): Handle selection of a word -> Expand back to include preceding dot/? ---
        if let selectedWordToken = tokens.first(where: { $0.kind == .word && $0.range == selection }),
           let wordIndex = tokens.firstIndex(of: selectedWordToken), wordIndex > 0 {
            let precedingToken = tokens[wordIndex - 1]
            if precedingToken.kind == .dot || precedingToken.kind == .optionalDot {
                 let gap = completeBuffer[precedingToken.range.upperBound..<selection.lowerBound]
                 if gap.isEmpty || gap.allSatisfy({ $0.isWhitespace }) {
                      let result = precedingToken.range.lowerBound..<selection.upperBound
                      let resultDesc = Buffer(completeBuffer: completeBuffer, selections: [SourceTextRange(range: result, buffer: completeBuffer)]).rawDescription
                      // print("[chainBwd] Logic A ('\(selectedWordToken.value)') -> Preceding Dot ('\(precedingToken.value)') -> \(resultDesc)")
                      return result // Result: |.word| or |?.word|
                 }
            }
        }

        // --- Step 2 (Logic B): Expand chain selection backward to include preceding dot/? ---
        // Check if the selection *doesn't* start with dot/? but is preceded by one.
        let firstTokenIndex = tokens.firstIndex(where: {$0.range.lowerBound == selection.lowerBound})
        if let index = firstTokenIndex, index > 0 {
             let currentFirstToken = tokens[index]
             // Ensure selection doesn't already start with the dot we might find
             if currentFirstToken.kind != .dot && currentFirstToken.kind != .optionalDot {
                  let precedingToken = tokens[index - 1]
                  if precedingToken.kind == .dot || precedingToken.kind == .optionalDot {
                       // Check adjacency
                       let gap = completeBuffer[precedingToken.range.upperBound..<selection.lowerBound]
                        if gap.isEmpty || gap.allSatisfy({ $0.isWhitespace }) {
                             // Selection is like |optional.value|. Expand to include preceding dot/?.
                             let result = precedingToken.range.lowerBound..<selection.upperBound
                             let resultDesc = Buffer(completeBuffer: completeBuffer, selections: [SourceTextRange(range: result, buffer: completeBuffer)]).rawDescription
                             // print("[chainBwd] Logic B (Expand chain for dot) -> \(resultDesc)")
                             return result // Result: |.optional.value| or |?.optional?.value|
                        }
                  }
             }
        }

        // --- Step 3 (Logic C): Handle selection starting with dot/? -> Expand back to include preceding word ---
        if let firstToken = tokens.first(where: {$0.range.lowerBound == selection.lowerBound}),
           (firstToken.kind == .dot || firstToken.kind == .optionalDot),
           let firstTokenIndex = tokens.firstIndex(of: firstToken), firstTokenIndex > 0 {

            let tokenBeforeDot = tokens[firstTokenIndex - 1]
            if tokenBeforeDot.kind == .word {
                let gap = completeBuffer[tokenBeforeDot.range.upperBound..<firstToken.range.lowerBound]
                if gap.isEmpty || gap.allSatisfy({$0.isWhitespace}) {
                     let result = tokenBeforeDot.range.lowerBound..<selection.upperBound
                     let resultDesc = Buffer(completeBuffer: completeBuffer, selections: [SourceTextRange(range: result, buffer: completeBuffer)]).rawDescription
                     // print("[chainBwd] Logic C ('\(completeBuffer[selection])') -> Preceding Word ('\(tokenBeforeDot.value)') -> \(resultDesc)")
                     return result // Result: |prevWord.word| or |prevWord?.word|
                }
            }
        }
        // print("[chainBwd] Fallback -> No Change")
        // No chain expansion rule applied for this selection
        return selection
    }

    private func findMatchingBrace(startIndex: Int, tokens: [Token]) -> Token? {
        // print("[findMatchingBrace] Start Index: \(startIndex)")
        guard startIndex < tokens.count else { return nil }
        let openToken = tokens[startIndex]
        guard openToken.kind == .bracket else { 
            // print("[findMatchingBrace] Token at start index is not a bracket: \(openToken)")
             return nil
        }
        
        let openChar = openToken.value
        let closeChar: String
        switch openChar {
            case "{": closeChar = "}"
            case "[": closeChar = "]"
            case "(": closeChar = ")"
            case "<": closeChar = ">"
            default: 
                // print("[findMatchingBrace] Not a supported opening bracket: \(openChar)")
                 return nil
        }
        // print("[findMatchingBrace] Looking for '\(closeChar)' matching '\(openChar)'...")
        
        var depth = 0
        // Iterate from the token *after* the starting one
        for i in (startIndex + 1)..<tokens.count {
            let currentToken = tokens[i]
            // print("[findMatchingBrace] Checking token: \(currentToken.value) (\\[\(i)]) Depth: \(depth)")
            if currentToken.kind == .bracket {
                if currentToken.value == openChar {
                    depth += 1
                    // print("[findMatchingBrace] ++ Depth now \(depth)")
                } else if currentToken.value == closeChar {
                    if depth == 0 {
                        // print("[findMatchingBrace] Found match at index \(i): \(currentToken)")
                        return currentToken // Found the matching closing brace
                    }
                    depth -= 1
                    // print("[findMatchingBrace] -- Depth now \(depth)")
                }
            }
        }
        // print("[findMatchingBrace] Reached end without finding match for index \(startIndex).")
        return nil // No matching closing brace found
    }

    // Function to expand selection within a dictionary context
    private func expandInDictionaryContext(_ selection: Range<String.Index>) -> Range<String.Index>? {
        // let initialDesc = Buffer(completeBuffer: completeBuffer, selections: [SourceTextRange(range: selection, buffer: completeBuffer)]).rawDescription
        // print("[dictCtx] Input: \(initialDesc)")

        // 1. Find innermost enclosing brackets []
        guard let (openBracket, closeBracket, contentRange) = findInnermostEnclosingPair(selection: selection, openChar: "[", closeChar: "]") else {
            // print("[dictCtx] Did not find enclosing [] brackets.")
            return nil // Not inside [] or selection prevents finding pair
        }
        let fullRange = openBracket.range.lowerBound..<closeBracket.range.upperBound
        
        // Basic Check: Is it likely a dictionary? Check for a colon within the content.
        let innerTokens = tokens.filter { $0.range.lowerBound >= contentRange.lowerBound && $0.range.upperBound <= contentRange.upperBound }
        guard innerTokens.contains(where: { $0.kind == .colon }) else {
            // print("[dictCtx] No colon found inside [], likely an Array.")
            return nil // Let Array context handle it
        }
        // print("[dictCtx] Found enclosing [] with a colon inside.")

        // --- Expansion Stages --- 

        // Stage 4: Selection is already the full range (including brackets)
        if selection == fullRange {
            // print("[dictCtx] Stage 4: Already full range -> No Change")
            return selection
        }

        // Stage 3: Selection is the content range (all pairs) -> Expand to include brackets
        if selection == contentRange {
            // print("[dictCtx] Stage 3: Content selected -> Include Brackets")
            return fullRange
        }
        
        // --- Stages within the contentRange --- 
        let pairsInfo = findDictionaryPairs(within: contentRange) // Helper needed
        
        // Find which pair(s) the selection overlaps
        let overlappingPairs = pairsInfo.filter { 
            ($0.keyRange.overlaps(selection) || $0.valueRange.overlaps(selection) || ($0.keyRange.upperBound == $0.valueRange.lowerBound && selection.contains($0.colonToken.range.lowerBound))) // Overlaps key, value, or colon
        }
        
        if overlappingPairs.count == 1 {
            let pair = overlappingPairs[0]
            let fullPairRange = pair.keyRange.lowerBound..<pair.valueRange.upperBound

            // Stage 2: Selection is the full pair -> Expand to all pairs (contentRange)
            if selection == fullPairRange {
                // print("[dictCtx] Stage 2: Full pair selected -> All Pairs Content")
                 // Ensure there's actually content to expand to
                 return contentRange.isEmpty ? selection : contentRange
            }

            // Stage 1: Selection is key OR value (but not full pair) -> Expand to full pair
            let selectionIsKey = pair.keyRange.lowerBound <= selection.lowerBound && pair.keyRange.upperBound >= selection.upperBound
            let selectionIsValue = pair.valueRange.lowerBound <= selection.lowerBound && pair.valueRange.upperBound >= selection.upperBound
            let selectionIsColon = selection.contains(pair.colonToken.range.lowerBound) // Simple colon check
            
            // --- Modified Logic ---
            if selectionIsValue && selection != fullPairRange {
                // Check if the value itself is a quoted string by looking at its bounds
                let valueText = completeBuffer[pair.valueRange]
                if valueText.hasPrefix("\"") && valueText.hasSuffix("\"") && valueText.count >= 2 {
                    // Value appears to be a string literal. Try string expansion first.
                    let stringExpansion = expandInStringContext(selection)
                    if stringExpansion != selection {
                        // String context expanded (e.g., content -> content+quotes)
                        // print("[dictCtx] Stage 1 (Value): Delegated to String Context -> Expanded")
                        return stringExpansion
                    }
                    // String context didn't expand further (e.g., already content+quotes).
                    // Fall through to expand to the full pair below.
                    // print("[dictCtx] Stage 1 (Value): String Context no change, proceeding to Full Pair")
                }
                // If not a string or string expansion didn't change anything, expand Value -> Full Pair
                // print("[dictCtx] Stage 1 (Value): Expanding -> Full Pair")
                return fullPairRange

            } else if (selectionIsKey || selectionIsColon) && selection != fullPairRange {
                 if selectionIsKey {
                     // Check if the key itself is a quoted string
                     let keyText = completeBuffer[pair.keyRange]
                     if keyText.hasPrefix("\"") && keyText.hasSuffix("\"") && keyText.count >= 2 {
                         // Pass the full key range to string context if selection is inside it,
                         // otherwise pass the selection itself.
                         let rangeForStringContext = pair.keyRange.contains(selection.lowerBound) ? pair.keyRange : selection
                         let stringExpansion = expandInStringContext(rangeForStringContext)

                         if stringExpansion != selection {
                             // String context expanded (e.g., content -> content+quotes)
                             // print("[dictCtx] Stage 1 (Key): Delegated to String Context -> Expanded")
                             return stringExpansion
                         }
                         // String context didn't expand further (e.g., selection was already content+quotes).
                         // Proceed to check if we should expand to the full pair.
                         // print("[dictCtx] Stage 1 (Key): String Context no change, proceeding to check Full Pair")
                         // If the selection *after* string context check matches the full key range,
                         // the next step is to expand to the full pair.
                         if selection == pair.keyRange {
                            // print("[dictCtx] Stage 1 (Key): Selection matches key range, expanding -> Full Pair")
                             return fullPairRange
                         }
                         // Otherwise (e.g., string context did nothing on partial key), stay put for now.
                         // Let the next expansion cycle handle it or fallback.
                         // print("[dictCtx] Stage 1 (Key): String Context no change, selection != key range -> No Change Yet")
                         return selection // Stay put
                     }
                      // If not a string, expand Key -> Full Pair
                      // print("[dictCtx] Stage 1 (Key - Not String): Expanding -> Full Pair")
                     return fullPairRange
                 } else if selectionIsColon {
                      // Colon still expands directly to full pair
                      // print("[dictCtx] Stage 1 (Colon): Expanding -> Full Pair")
                      return fullPairRange
                 }
                 // Should not be reached, but fallback
                  return fullPairRange
             }
             // --- End Modified Logic ---
            
        } else if overlappingPairs.count > 1 {
            // Selection spans multiple pairs -> Expand to all pairs (contentRange)
            return contentRange.isEmpty ? selection : contentRange
        } else if !contentRange.isEmpty {
            // Selection is in whitespace/comma between pairs -> Expand to all pairs
            return contentRange
        }

        // print("[dictCtx] No applicable expansion step found -> No Change")
        return selection // Return current selection if no expansion rule applied *within* dict context
    }
    
    // Helper to find dictionary key-value pairs within a range
    private func findDictionaryPairs(within contentRange: Range<String.Index>) -> [(keyRange: Range<String.Index>, valueRange: Range<String.Index>, colonToken: Token)] {
        guard !contentRange.isEmpty else { return [] }
        var pairs: [(keyRange: Range<String.Index>, valueRange: Range<String.Index>, colonToken: Token)] = []
        // Get tokens strictly within the content range, excluding whitespace and outer brackets
        let relevantTokens = tokens.filter { 
            $0.range.lowerBound >= contentRange.lowerBound && 
            $0.range.upperBound <= contentRange.upperBound &&
            $0.kind != .whitespace
        }
        
        guard !relevantTokens.isEmpty else { return [] }

        var currentPairStartIndex = 0
        while currentPairStartIndex < relevantTokens.count {
            // Find the colon for the current pair starting from currentPairStartIndex
            guard let colonIndex = relevantTokens[currentPairStartIndex...].firstIndex(where: { $0.kind == .colon }) else {
                 break // No more colons found in the remaining tokens
            }
            let colonToken = relevantTokens[colonIndex]

            // --- Key Range Calculation ---
            let keyStartIndex = currentPairStartIndex
            let keyEndIndex = colonIndex - 1 // Index of the token just before the colon
            guard keyStartIndex <= keyEndIndex else { break } // Should not happen if input is valid dict
            let keyStartToken = relevantTokens[keyStartIndex]
            let keyEndToken = relevantTokens[keyEndIndex]
            let keyRange = keyStartToken.range.lowerBound..<keyEndToken.range.upperBound

            // --- Value Range Calculation ---
            let valueStartIndex = colonIndex + 1 // Index of the token just after the colon
            guard valueStartIndex < relevantTokens.count else { break } // No tokens after colon

            // Find the index of the next comma, starting search *after* the colon
            let commaSearchStartIndex = valueStartIndex
            let nextCommaIndex = relevantTokens[commaSearchStartIndex...].firstIndex(where: { $0.kind == .comma })

            let valueEndIndex: Int
            if let commaIndex = nextCommaIndex {
                valueEndIndex = commaIndex - 1 // Value ends at token before the comma
                currentPairStartIndex = commaIndex + 1 // Next pair starts after the comma
            } else {
                valueEndIndex = relevantTokens.endIndex - 1 // Value ends at the last relevant token
                currentPairStartIndex = relevantTokens.endIndex // Stop iteration
            }
            
            guard valueStartIndex <= valueEndIndex else { break } // No tokens for value (e.g., key: ,)
            let valueStartToken = relevantTokens[valueStartIndex]
            let valueEndToken = relevantTokens[valueEndIndex]
            let valueRange = valueStartToken.range.lowerBound..<valueEndToken.range.upperBound

            // Add the found pair
            pairs.append((keyRange: keyRange, valueRange: valueRange, colonToken: colonToken))
        }

        return pairs
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

    init(range: Range<String.Index>, buffer: String) {
         let startOffset = buffer.distance(from: buffer.startIndex, to: range.lowerBound)
         let endOffset = buffer.distance(from: buffer.startIndex, to: range.upperBound)
         // Assuming single line for simplicity in debugging
         self.init(start: SourceTextPosition(line: 0, column: startOffset),
                   end: SourceTextPosition(line: 0, column: endOffset))
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

