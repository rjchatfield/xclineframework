import Foundation

/// Represents a token in Swift code
public struct Token: Equatable {
    /// The type of token
    public enum Kind: Equatable {
        case word
        case whitespace
        case quote
        case bracket
        case comma
        case colon
        case dot
        case arrow
        case other
    }
    
    /// The kind of token
    public let kind: Kind
    
    /// The string value of the token
    public let value: String
    
    /// The range of the token in the original text
    public let range: Range<String.Index>
    
    public init(kind: Kind, value: String, range: Range<String.Index>) {
        self.kind = kind
        self.value = value
        self.range = range
    }
}

/// A context in which tokens exist
public enum TokenContext: Equatable {
    case root
    case string
    case array
    case dictionary
    case function
    case closure
    case generic
    case parameter
    case type
}

/// A stack of contexts to track nesting
public struct ContextStack {
    private var stack: [TokenContext] = [.root]
    
    public var current: TokenContext { stack.last! }
    
    public mutating func push(_ context: TokenContext) {
        stack.append(context)
    }
    
    public mutating func pop() -> TokenContext {
        guard stack.count > 1 else { return .root }
        return stack.removeLast()
    }
} 