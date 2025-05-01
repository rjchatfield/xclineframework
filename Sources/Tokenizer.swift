import Foundation

public struct Tokenizer {
    private let text: String
    private var index: String.Index
    private var context: ContextStack
    
    public init(text: String) {
        self.text = text
        self.index = text.startIndex
        self.context = ContextStack()
    }
    
    public mutating func tokenize() -> [Token] {
        var tokens: [Token] = []
        
        while index < text.endIndex {
            let char = text[index]
            
            // Skip whitespace
            if char.isWhitespace {
                let start = index
                while index < text.endIndex && text[index].isWhitespace {
                    index = text.index(after: index)
                }
                tokens.append(Token(
                    kind: .whitespace,
                    value: String(text[start..<index]),
                    range: start..<index
                ))
                continue
            }
            
            // Handle quotes
            if char == "\"" {
                let start = index
                index = text.index(after: index)
                tokens.append(Token(
                    kind: .quote,
                    value: "\"",
                    range: start..<index
                ))
                context.push(.string)
                continue
            }
            
            // Handle brackets
            if "([{<".contains(char) {
                let start = index
                index = text.index(after: index)
                tokens.append(Token(
                    kind: .bracket,
                    value: String(char),
                    range: start..<index
                ))
                switch char {
                case "(": context.push(.function)
                case "[": context.push(.array)
                case "{": context.push(.closure)
                case "<": context.push(.generic)
                default: break
                }
                continue
            }
            
            // Handle closing brackets
            if ")]}>".contains(char) {
                let start = index
                index = text.index(after: index)
                tokens.append(Token(
                    kind: .bracket,
                    value: String(char),
                    range: start..<index
                ))
                _ = context.pop()
                continue
            }
            
            // Handle other special characters
            if ",:.".contains(char) {
                let start = index
                index = text.index(after: index)
                let kind: Token.Kind = switch char {
                case ",": .comma
                case ":": .colon
                case ".": .dot
                default: .other
                }
                tokens.append(Token(
                    kind: kind,
                    value: String(char),
                    range: start..<index
                ))
                continue
            }
            
            // Handle words
            let start = index
            while index < text.endIndex {
                let char = text[index]
                if char.isWhitespace || ",:.[]{}()<>\"".contains(char) {
                    break
                }
                index = text.index(after: index)
            }
            tokens.append(Token(
                kind: .word,
                value: String(text[start..<index]),
                range: start..<index
            ))
        }
        
        return tokens
    }
} 